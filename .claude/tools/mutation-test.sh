#!/bin/bash
# mutation-test.sh — Swift mutation testing tool (muter-compatible operators)
#
# Mutation operators (matching muter's mutation_operators.md):
#   NegateConditionals:     == ↔ !=, > ↔ <, >= ↔ <=, < ↔ >, <= ↔ >=
#   ChangeLogicalConnector: && ↔ ||
#   BooleanReturn:          return true ↔ return false
#   RemoveSideEffects:      removes void function call lines
#   SwapTernary:            cond ? a : b → cond ? b : a
#
# Correctness:
#   - Per-occurrence atomic mutations (each operator occurrence = separate test run)
#   - Skips string literals, line comments, block comments, muter:disable blocks
#   - Follows muter's assumption: spaces around operators required for > and <
#
# Performance:
#   - xcodebuild mode: build-for-testing once, then incremental build + test-without-building per mutation
#   - spm mode: swift build once, then swift build + swift test per mutation (incremental)
#   - Mutations that cause compile errors are skipped (no test run wasted)
#   - Pre-boots simulator to avoid repeated launch/kill cycles
#   - Single test file matching: runs only {Class}Tests.swift instead of full suite
#   - Git-diff line filter: mutates only changed lines when --git-diff is used
#   - Parallel execution: splits mutations across CPU cores with cloned simulators
#
# Usage (xcodebuild):
#   bash .claude/tools/mutation-test.sh --file <swift-file> --scheme <scheme> \
#     [--threshold <pct>] [--destination <dest>] [--test-file <test>] \
#     [--project-root <path>] [--git-diff [base]] [--jobs <n>] [--quiet]
#
# Usage (Swift Package Manager):
#   bash .claude/tools/mutation-test.sh --file <swift-file> --package-path <path> \
#     [--threshold <pct>] [--test-file <test>] [--git-diff [base]] [--quiet]

set -uo pipefail

FILE=""
SCHEME=""
THRESHOLD=60
DESTINATION="platform=iOS Simulator,name=iPhone 16"
PACKAGE_PATH=""
TEST_FILE=""
PROJECT_ROOT=""
GIT_DIFF_BASE=""
JOBS=0
QUIET=false
START_TIME=$(date +%s)

while [[ $# -gt 0 ]]; do
    case $1 in
        --file)         FILE="$2";         shift 2 ;;
        --scheme)       SCHEME="$2";       shift 2 ;;
        --threshold)    THRESHOLD="$2";    shift 2 ;;
        --destination)  DESTINATION="$2";  shift 2 ;;
        --package-path) PACKAGE_PATH="$2"; shift 2 ;;
        --test-file)    TEST_FILE="$2";    shift 2 ;;
        --project-root) PROJECT_ROOT="$2"; shift 2 ;;
        --git-diff)
            # Next arg is the base branch (optional, default: main)
            if [[ $# -ge 2 && ! "$2" =~ ^-- ]]; then
                GIT_DIFF_BASE="$2"; shift 2
            else
                GIT_DIFF_BASE="main"; shift
            fi
            ;;
        --jobs)         JOBS="$2";         shift 2 ;;
        --quiet)        QUIET=true;        shift ;;
        *)              shift ;;
    esac
done

# ── SPM auto-detection ─────────────────────────────────────────────────────────
# Handles two cases:
#   a) --scheme given but project is actually a pure SPM library (no .xcworkspace)
#   b) Neither --scheme nor --package-path given, but Package.swift is present
# Regular iOS projects have a .xcworkspace, so the nullglob check won't trigger.
if [[ -z "$PACKAGE_PATH" ]]; then
    _DETECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    if [[ -f "$_DETECT_ROOT/Package.swift" ]]; then
        shopt -s nullglob
        _WS_FILES=("$_DETECT_ROOT"/*.xcworkspace)
        shopt -u nullglob
        if [[ ${#_WS_FILES[@]} -eq 0 ]]; then
            [[ -n "$SCHEME" ]] && echo "Note: SPM library detected (no .xcworkspace). Switching to SPM mode."
            PACKAGE_PATH="$_DETECT_ROOT"
            SCHEME=""
        fi
    fi
fi

if [[ -z "$FILE" ]]; then
    echo "Usage: mutation-test.sh --file <swift-file> (--scheme <scheme> | --package-path <path>) [--threshold <n>]"
    exit 1
fi

if [[ -z "$SCHEME" && -z "$PACKAGE_PATH" ]]; then
    echo "Error: provide either --scheme (xcodebuild) or --package-path (SPM)"
    exit 1
fi

if [[ ! -f "$FILE" ]]; then
    echo "Error: File not found: $FILE"
    exit 1
fi

# ── Test file auto-discovery ─────────────────────────────────────────────────
# Convention: {ProductionClass}.swift → {ProductionClass}Tests.swift
TEST_FILTER=""
if [[ -z "$TEST_FILE" ]]; then
    BASENAME=$(basename "$FILE" .swift)
    SEARCH_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || dirname "$FILE")}"
    FOUND_TEST=$(find "$SEARCH_ROOT" -name "${BASENAME}Tests.swift" -not -path '*/.*' -not -path '*/DerivedData/*' 2>/dev/null | sort | head -1)
    if [[ -n "$FOUND_TEST" ]]; then
        TEST_FILE="$FOUND_TEST"
        echo "Auto-discovered test file: $(basename "$TEST_FILE")"
    fi
fi

if [[ -n "$TEST_FILE" ]]; then
    if [[ ! -f "$TEST_FILE" ]]; then
        echo "Warning: --test-file not found: $TEST_FILE (falling back to full suite)"
        TEST_FILE=""
    else
        TEST_CLASS=$(basename "$TEST_FILE" .swift)
        if [[ -n "$PACKAGE_PATH" ]]; then
            TEST_FILTER="--filter ${TEST_CLASS}"
        else
            # Derive test target from directory structure: {Module}Tests/{path}
            TEST_TARGET=""
            TEST_DIR=$(dirname "$TEST_FILE")
            while [[ "$TEST_DIR" != "/" && "$TEST_DIR" != "." ]]; do
                DIR_NAME=$(basename "$TEST_DIR")
                if [[ "$DIR_NAME" == *Tests ]]; then
                    TEST_TARGET="$DIR_NAME"
                    break
                fi
                TEST_DIR=$(dirname "$TEST_DIR")
            done
            if [[ -n "$TEST_TARGET" ]]; then
                TEST_FILTER="-only-testing:${TEST_TARGET}/${TEST_CLASS}"
            else
                TEST_FILTER="-only-testing:${TEST_CLASS}"
            fi
        fi
    fi
fi

# ── Git-diff changed lines ──────────────────────────────────────────────────
GIT_DIFF_LINES_FILE=""
if [[ -n "$GIT_DIFF_BASE" ]]; then
    GIT_DIFF_LINES_FILE=$(mktemp /tmp/mtest-difflines.XXXXXX.json)
    # Parse unified diff to extract changed line numbers in the target file
    python3 -c "
import subprocess, json, sys, re
base = sys.argv[1]
filepath = sys.argv[2]
try:
    diff = subprocess.check_output(
        ['git', 'diff', base, '--unified=0', '--', filepath],
        stderr=subprocess.DEVNULL, text=True
    )
except Exception:
    json.dump([], sys.stdout)
    sys.exit(0)

lines = set()
for m in re.finditer(r'@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@', diff):
    start = int(m.group(1))
    count = int(m.group(2)) if m.group(2) else 1
    if count == 0:
        continue
    for l in range(start, start + count):
        lines.add(l)
json.dump(sorted(lines), sys.stdout)
" "$GIT_DIFF_BASE" "$FILE" > "$GIT_DIFF_LINES_FILE"
    DIFF_LINE_COUNT=$(python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))))" "$GIT_DIFF_LINES_FILE")
    if [[ "$DIFF_LINE_COUNT" -eq 0 ]]; then
        echo "No changed lines in $(basename "$FILE") vs $GIT_DIFF_BASE — skipping."
        rm -f "$GIT_DIFF_LINES_FILE"
        exit 0
    fi
    echo "Git-diff mode: filtering to $DIFF_LINE_COUNT changed lines vs $GIT_DIFF_BASE"
fi

# ── Simulator pre-boot (xcodebuild only) ────────────────────────────────────
SIM_UDID=""
CLONED_SIM_UDIDS=()
if [[ -z "$PACKAGE_PATH" ]]; then
    # Extract simulator name from DESTINATION (e.g. "platform=iOS Simulator,name=iPhone 16")
    SIM_NAME=$(echo "$DESTINATION" | sed -n 's/.*name=\([^,]*\).*/\1/p')
    if [[ -n "$SIM_NAME" ]]; then
        SIM_UDID=$(xcrun simctl list devices available -j 2>/dev/null | \
            python3 -c "
import json, sys
data = json.load(sys.stdin)
name = sys.argv[1]
for runtime, devices in data.get('devices', {}).items():
    if 'iOS' not in runtime:
        continue
    for d in devices:
        if d['name'] == name and d['state'] != 'Shutdown':
            print(d['udid']); sys.exit(0)
for runtime, devices in data.get('devices', {}).items():
    if 'iOS' not in runtime:
        continue
    for d in devices:
        if d['name'] == name:
            print(d['udid']); sys.exit(0)
" "$SIM_NAME" 2>/dev/null)
        if [[ -n "$SIM_UDID" ]]; then
            # Boot if not already booted
            SIM_STATE=$(xcrun simctl list devices -j 2>/dev/null | \
                python3 -c "
import json, sys
data = json.load(sys.stdin)
udid = sys.argv[1]
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d['udid'] == udid:
            print(d['state']); sys.exit(0)
" "$SIM_UDID" 2>/dev/null)
            if [[ "$SIM_STATE" != "Booted" ]]; then
                printf "Pre-booting simulator %s (%s)... " "$SIM_NAME" "$SIM_UDID"
                xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
                echo "done"
            fi
        fi
    fi
fi

# ── Determine parallelism ───────────────────────────────────────────────────
if [[ "$JOBS" -eq 0 ]]; then
    CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || echo 2)
    JOBS=$(( CPU_CORES / 2 ))
    [[ "$JOBS" -lt 1 ]] && JOBS=1
    [[ "$JOBS" -gt 4 ]] && JOBS=4
fi
# SPM mode: parallel not supported (no simulator cloning)
if [[ -n "$PACKAGE_PATH" && "$JOBS" -gt 1 ]]; then
    JOBS=1
fi

# ── Backup & cleanup ──────────────────────────────────────────────────────────
BACKUP=$(mktemp /tmp/mtest-backup-XXXXXX)
MUTATIONS_FILE=$(mktemp /tmp/mtest-mutations-XXXXXX)
FINDER_PY=$(mktemp /tmp/mtest-finder-XXXXXX)
APPLIER_PY=$(mktemp /tmp/mtest-applier-XXXXXX)
BUILD_LOG=$(mktemp /tmp/mtest-build-XXXXXX)
DD_BASE=""

cp "$FILE" "$BACKUP"

cleanup() {
    cp "$BACKUP" "$FILE"
    rm -f "$BACKUP" "$MUTATIONS_FILE" "$FINDER_PY" "$APPLIER_PY" "$BUILD_LOG"
    [[ -n "$GIT_DIFF_LINES_FILE" ]] && rm -f "$GIT_DIFF_LINES_FILE"
    # Remove cloned simulators created for parallel execution
    for cid in ${CLONED_SIM_UDIDS[@]+"${CLONED_SIM_UDIDS[@]}"}; do
        xcrun simctl shutdown "$cid" 2>/dev/null || true
        xcrun simctl delete "$cid" 2>/dev/null || true
    done
    # Clean up per-worker DerivedData copies
    if [[ -n "$DD_BASE" ]]; then
        rm -rf "$DD_BASE" "${DD_BASE}"-worker-* 2>/dev/null
    fi
    # Clean up worker result files (PID-scoped)
    rm -f /tmp/mtest-worker-$$-*.result 2>/dev/null
    rm -f /tmp/mtest-flock-$$ 2>/dev/null
}
trap cleanup EXIT

# ── Python: mutation point finder ─────────────────────────────────────────────
cat > "$FINDER_PY" << 'PYEOF'
"""
Swift mutation point finder — muter-compatible operators.
Outputs JSON array of mutation descriptors sorted by byte offset.
Usage: python3 finder.py <swift-file>
"""
import sys, json, re

source = open(sys.argv[1], encoding='utf-8').read()

# ── Tokenizer: build a byte mask (1=code, 0=skip) ────────────────────────────
def build_code_mask(src):
    """
    State machine over the source. Returns a bytearray where 1 = code region,
    0 = comment / string literal / muter:disabled block.
    """
    n = len(src)
    mask = bytearray(n)
    i = 0
    disabled = False  # muter:disable active?
    code_start = 0

    def mark_code(end):
        if not disabled:
            for x in range(code_start, end):
                mask[x] = 1

    while i < n:
        # Triple-quoted string """..."""
        if src[i:i+3] == '"""':
            mark_code(i)
            j = src.find('"""', i + 3)
            i = (j + 3) if j != -1 else n
            code_start = i
            continue

        # Line comment //...
        if src[i:i+2] == '//':
            mark_code(i)
            j = src.find('\n', i)
            end = j if j != -1 else n
            txt = src[i:end]
            if 'muter:disable' in txt:
                disabled = True
            elif 'muter:enable' in txt:
                disabled = False
            i = end
            code_start = i
            continue

        # Block comment /*...*/
        if src[i:i+2] == '/*':
            mark_code(i)
            j = src.find('*/', i + 2)
            i = (j + 2) if j != -1 else n
            code_start = i
            continue

        # String literal "..."
        if src[i] == '"':
            mark_code(i)
            j = i + 1
            while j < n:
                if src[j] == '\\':
                    j += 2
                    continue
                if src[j] == '"':
                    j += 1
                    break
                j += 1
            i = j
            code_start = i
            continue

        i += 1

    mark_code(n)
    return mask

mask = build_code_mask(source)
n = len(source)


def is_code(pos):
    return 0 <= pos < n and mask[pos] == 1


# ── Line/column lookup ────────────────────────────────────────────────────────
line_starts = [0]
for idx, ch in enumerate(source):
    if ch == '\n':
        line_starts.append(idx + 1)

def to_linecol(off):
    lo, hi = 0, len(line_starts) - 1
    while lo < hi:
        mid = (lo + hi + 1) // 2
        if line_starts[mid] <= off:
            lo = mid
        else:
            hi = mid - 1
    return lo + 1, off - line_starts[lo] + 1


mutations = []
mid = 0


# ── Negate Conditionals & Change Logical Connector ───────────────────────────
BINARY_OPS = [
    ('==', '!=', 'NegateConditionals'),
    ('!=', '==', 'NegateConditionals'),
    ('>=', '<=', 'NegateConditionals'),
    ('<=', '>=', 'NegateConditionals'),
    ('&&', '||', 'ChangeLogicalConnector'),
    ('||', '&&', 'ChangeLogicalConnector'),
]

for op, newop, kind in BINARY_OPS:
    for m in re.finditer(re.escape(op), source):
        pos = m.start()
        if not is_code(pos):
            continue
        # Exclude === and !==
        if op == '==' and source[pos+2:pos+3] == '=':
            continue
        if op == '!=' and source[pos+2:pos+3] == '=':
            continue
        ln, col = to_linecol(pos)
        mutations.append({
            'id': mid, 'line': ln, 'col': col,
            'op': op, 'newop': newop, 'type': kind,
            'offset': pos, 'length': len(op),
        })
        mid += 1

# > and < require careful handling to avoid generics and arrows
for op, newop in [('>', '<'), ('<', '>')]:
    for m in re.finditer(re.escape(op), source):
        pos = m.start()
        if not is_code(pos):
            continue
        before = source[pos - 1] if pos > 0 else ' '
        after  = source[pos + 1] if pos + 1 < n else ' '
        # Skip ->, =>, <<=, >>=, >>, <<
        if before in ('-', '='):
            continue
        # Skip >=, <=
        if after == '=':
            continue
        # Skip >>, <<
        if after == op:
            continue
        # Generics heuristic (muter docs: assume spaces around operators)
        # If not surrounded by at least one space, it's likely a generic
        if not (before.isspace() or before in ')]}') and not after.isspace():
            continue
        ln, col = to_linecol(pos)
        mutations.append({
            'id': mid, 'line': ln, 'col': col,
            'op': op, 'newop': newop, 'type': 'NegateConditionals',
            'offset': pos, 'length': 1,
        })
        mid += 1


# ── Boolean Return ────────────────────────────────────────────────────────────
for pat, newop in [
    (r'\breturn\s+true\b',  'return false'),
    (r'\breturn\s+false\b', 'return true'),
]:
    for m in re.finditer(pat, source):
        pos = m.start()
        if not is_code(pos):
            continue
        ln, col = to_linecol(pos)
        mutations.append({
            'id': mid, 'line': ln, 'col': col,
            'op': m.group(), 'newop': newop, 'type': 'BooleanReturn',
            'offset': pos, 'length': len(m.group()),
        })
        mid += 1


# ── Remove Side Effects ───────────────────────────────────────────────────────
# Identify lines that appear to be void function calls (no result stored/returned).
# Heuristic: line matches <identifier>[.<identifier>]*(<args>) with no assignment.
SKIP_FIRST_WORDS = {
    'if', 'else', 'for', 'while', 'guard', 'switch', 'case', 'return',
    'break', 'continue', 'throw', 'defer', 'do', 'try', 'await',
    'let', 'var', 'func', 'class', 'struct', 'enum', 'import',
    'typealias', 'override', 'private', 'public', 'internal', 'fileprivate',
    'static', 'final', 'open', 'lazy', 'weak', 'unowned',
    'print', 'debugPrint', 'fatalError', 'abort', 'exit',
    'assert', 'assertionFailure', 'precondition', 'preconditionFailure',
}

VOID_CALL_PAT = re.compile(
    r'^[ \t]*((?:(?:self|super|[a-zA-Z_]\w*)\??\.)*[a-zA-Z_]\w*)\s*\([^)]*\)\s*;?\s*$'
)

for line_idx, ls in enumerate(line_starts):
    if not is_code(ls):
        continue
    next_ls = line_starts[line_idx + 1] if line_idx + 1 < len(line_starts) else n
    raw_line = source[ls:next_ls]
    line_text = raw_line.rstrip('\n')
    stripped  = line_text.strip()

    if not stripped:
        continue
    m = VOID_CALL_PAT.match(line_text)
    if not m:
        continue
    first_word = stripped.split('.')[0].split('(')[0].strip()
    if first_word in SKIP_FIRST_WORDS:
        continue
    # Must not contain assignment (except inside string literals, but we're already in code)
    if re.search(r'(?<![=!<>])=(?!=)', stripped):
        continue

    ln = line_idx + 1
    mutations.append({
        'id': mid, 'line': ln, 'col': 1,
        'op': stripped, 'newop': '// [muted:removed]',
        'type': 'RemoveSideEffects',
        'offset': ls, 'length': len(line_text),
        'is_line_removal': True,
    })
    mid += 1


# ── Swap Ternary ──────────────────────────────────────────────────────────────
def find_ternaries(src, msk):
    """
    Finds ternary expressions: cond ? then_expr : else_expr
    Returns list of dicts with then/else byte ranges.
    Handles nested parens/brackets but not nested ternaries (kept simple).
    """
    results = []
    i = 0
    nn = len(src)

    while i < nn:
        # Find a ? that is in code and is not ??
        if src[i] != '?' or not msk[i]:
            i += 1
            continue
        if i > 0 and src[i - 1] == '?':
            i += 1
            continue  # nil-coalescing ??
        if i + 1 < nn and src[i + 1] == '?':
            i += 1
            continue  # nil-coalescing ??

        q_pos = i
        # Skip Optional ? — in Swift, ternary ? always has whitespace before it
        if q_pos > 0 and not src[q_pos - 1].isspace():
            i += 1
            continue
        # Scan for then-expression start (skip whitespace)
        j = i + 1
        while j < nn and src[j] in ' \t':
            j += 1
        then_start = j

        # Find the matching colon at depth 0
        depth = 0
        found_colon = -1
        while j < nn:
            c = src[j]
            if not msk[j]:
                j += 1
                continue
            if c in '([{':
                depth += 1
            elif c in ')]}':
                depth -= 1
                if depth < 0:
                    break  # we left the enclosing context
            elif c == '?' and not (j + 1 < nn and src[j + 1] == '?') \
                          and not (j > 0 and src[j - 1] == '?'):
                depth += 1  # nested ternary
            elif c == ':' and depth == 0:
                found_colon = j
                break
            j += 1

        if found_colon == -1:
            i += 1
            continue

        then_end = found_colon
        # Trim trailing whitespace from then_text
        te = then_end
        while te > then_start and src[te - 1] in ' \t':
            te -= 1

        # Scan for else-expression start
        k = found_colon + 1
        while k < nn and src[k] in ' \t':
            k += 1
        else_start = k

        # Find end of else expression (stop at ; , \n closing-bracket at depth 0)
        depth2 = 0
        while k < nn:
            c = src[k]
            if not msk[k]:
                k += 1
                continue
            if c in '([{':
                depth2 += 1
            elif c in ')]}':
                depth2 -= 1
                if depth2 < 0:
                    break
            elif c in ';\n' and depth2 == 0:
                break
            elif c == ',' and depth2 == 0:
                break
            k += 1
        else_end = k
        # Trim trailing whitespace
        ee = else_end
        while ee > else_start and src[ee - 1] in ' \t':
            ee -= 1

        if te > then_start and ee > else_start:
            results.append({
                'q_pos': q_pos,
                'then_start': then_start,
                'then_end': te,
                'colon_pos': found_colon,
                'else_start': else_start,
                'else_end': ee,
            })

        i = q_pos + 1

    return results

for t in find_ternaries(source, mask):
    then_text = source[t['then_start']:t['then_end']]
    else_text = source[t['else_start']:t['else_end']]
    ln, col = to_linecol(t['q_pos'])
    mutations.append({
        'id': mid, 'line': ln, 'col': col,
        'op':    f"? {then_text.strip()} : {else_text.strip()}",
        'newop': f"? {else_text.strip()} : {then_text.strip()}",
        'type': 'SwapTernary',
        'offset': t['q_pos'],        # used only for sort & display
        'length': 0,                 # applier uses then/else ranges directly
        'then_start': t['then_start'],
        'then_end':   t['then_end'],
        'else_start': t['else_start'],
        'else_end':   t['else_end'],
    })
    mid += 1


# ── Output ────────────────────────────────────────────────────────────────────
mutations.sort(key=lambda m: m['offset'])
for i, m in enumerate(mutations):
    m['id'] = i

print(json.dumps(mutations, ensure_ascii=False))
PYEOF


# ── Python: single-mutation applier ───────────────────────────────────────────
cat > "$APPLIER_PY" << 'PYEOF'
"""
Apply one mutation (JSON string as argv[2]) to the Swift file at argv[1].
Writes the mutated file in-place.
"""
import sys, json

filepath = sys.argv[1]
mut      = json.loads(sys.argv[2])

with open(filepath, encoding='utf-8') as f:
    src = f.read()

kind = mut['type']

if kind == 'SwapTernary':
    ts, te = mut['then_start'], mut['then_end']
    es, ee = mut['else_start'], mut['else_end']
    then_text = src[ts:te]
    else_text = src[es:ee]
    # Replace right-to-left to preserve offsets
    result = src[:ts] + else_text + src[te:es] + then_text + src[ee:]

elif kind == 'RemoveSideEffects':
    off, length = mut['offset'], mut['length']
    line_text = src[off:off + length]
    indent = len(line_text) - len(line_text.lstrip())
    replacement = line_text[:indent] + '// [muted:removed] ' + line_text[indent:].rstrip()
    result = src[:off] + replacement + src[off + length:]

else:
    off, length, newop = mut['offset'], mut['length'], mut['newop']
    result = src[:off] + newop + src[off + length:]

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(result)
PYEOF


# ── Run finder ────────────────────────────────────────────────────────────────
python3 "$FINDER_PY" "$FILE" > "$MUTATIONS_FILE"

TOTAL_FOUND=$(python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))))" "$MUTATIONS_FILE")

# ── Git-diff filter: keep only mutations on changed lines ────────────────
if [[ -n "$GIT_DIFF_LINES_FILE" && -f "$GIT_DIFF_LINES_FILE" ]]; then
    FILTERED_FILE=$(mktemp /tmp/mtest-filtered.XXXXXX.json)
    python3 -c "
import json, sys
mutations = json.load(open(sys.argv[1]))
changed = set(json.load(open(sys.argv[2])))
filtered = [m for m in mutations if m['line'] in changed]
for i, m in enumerate(filtered):
    m['id'] = i
json.dump(filtered, open(sys.argv[3], 'w'), ensure_ascii=False)
" "$MUTATIONS_FILE" "$GIT_DIFF_LINES_FILE" "$FILTERED_FILE"
    mv "$FILTERED_FILE" "$MUTATIONS_FILE"
fi

TOTAL=$(python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))))" "$MUTATIONS_FILE")

echo ""
echo "Mutation Testing: $(basename "$FILE")"
if [[ -n "$PACKAGE_PATH" ]]; then
    printf "  Mode: SPM | Package: %s\n" "$PACKAGE_PATH"
else
    printf "  Mode: xcodebuild | Scheme: %s | Jobs: %d\n" "$SCHEME" "$JOBS"
fi
printf "  Threshold: %s%% | Mutations: %d" "$THRESHOLD" "$TOTAL"
if [[ -n "$GIT_DIFF_LINES_FILE" ]]; then
    printf " (filtered from %d via git-diff vs %s)" "$TOTAL_FOUND" "$GIT_DIFF_BASE"
fi
echo ""
if [[ -n "$TEST_FILE" ]]; then
    printf "  Test file: %s\n" "$(basename "$TEST_FILE")"
else
    echo "  Test file: full suite (no matching test file found)"
fi
echo ""

if [[ "$TOTAL" -eq 0 ]]; then
    echo "  No applicable mutation operators found in this file."
    exit 0
fi

# ── Initial build ─────────────────────────────────────────────────────────────
printf "Building for testing (once)... "
if [[ -n "$PACKAGE_PATH" ]]; then
    if ! swift build --package-path "$PACKAGE_PATH" 2>"$BUILD_LOG"; then
        echo "FAILED"
        echo ""
        echo "⛔ Initial build failed. Fix build errors before running mutation testing."
        [[ -s "$BUILD_LOG" ]] && head -20 "$BUILD_LOG"
        exit 1
    fi
else
    DD_BASE=$(mktemp -d /tmp/mtest-dd.XXXXXX)
    if ! xcodebuild build-for-testing \
            -scheme "$SCHEME" \
            -destination "$DESTINATION" \
            -derivedDataPath "$DD_BASE" \
            -quiet 2>"$BUILD_LOG"; then
        echo "FAILED"
        echo ""
        echo "⛔ Initial build failed. Fix build errors before running mutation testing."
        [[ -s "$BUILD_LOG" ]] && head -20 "$BUILD_LOG"
        exit 1
    fi
fi
echo "done"

# ── Worker function ───────────────────────────────────────────────────────────
# run_mutation_worker <worker-id> <start-idx> <end-idx> <sim-destination> <result-file> [<dd-path>]
# Processes mutations [start, end) sequentially on the given simulator/destination.
run_mutation_worker() {
    local W_ID="$1" W_START="$2" W_END="$3" W_DEST="$4" W_RESULT="$5"
    local W_DD="${6:-}"
    local w_killed=0 w_skipped=0
    local w_survived_lines=""

    for i in $(seq "$W_START" $((W_END - 1))); do
        MUT_DATA=$(python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
m = d[int(sys.argv[2])]
print(json.dumps(m))
print(m['line'], m['col'], m['type'])
print(m['op'][:40])
print(m['newop'][:40])
" "$MUTATIONS_FILE" "$i")

        MUT_JSON=$(echo "$MUT_DATA" | sed -n '1p')
        read -r MUT_LINE MUT_COL MUT_TYPE <<< "$(echo "$MUT_DATA" | sed -n '2p')"
        MUT_OP=$(echo "$MUT_DATA" | sed -n '3p')
        MUT_NEWOP=$(echo "$MUT_DATA" | sed -n '4p')

        LABEL="  [${i}] line ${MUT_LINE}: ${MUT_OP} → ${MUT_NEWOP} (${MUT_TYPE})"

        # Apply mutation (serialize file access with flock when parallel)
        if [[ "$JOBS" -gt 1 ]]; then
            exec 9>/tmp/mtest-flock-$$
            flock 9
        fi

        if ! python3 "$APPLIER_PY" "$FILE" "$MUT_JSON"; then
            cp "$BACKUP" "$FILE"
            [[ "$JOBS" -gt 1 ]] && flock -u 9
            [[ "$QUIET" == "false" ]] && printf "%-80s ... apply-error\n" "$LABEL"
            w_skipped=$((w_skipped + 1))
            continue
        fi

        local build_ok=true
        if [[ -n "$PACKAGE_PATH" ]]; then
            if ! swift build --package-path "$PACKAGE_PATH" 2>/dev/null; then
                build_ok=false
            fi
        else
            local -a build_args=(xcodebuild build-for-testing -scheme "$SCHEME" -destination "$W_DEST" -quiet)
            [[ -n "$W_DD" ]] && build_args+=(-derivedDataPath "$W_DD")
            if ! "${build_args[@]}" 2>/dev/null; then
                build_ok=false
            fi
        fi

        if [[ "$build_ok" == "false" ]]; then
            cp "$BACKUP" "$FILE"
            [[ "$JOBS" -gt 1 ]] && flock -u 9
            [[ "$QUIET" == "false" ]] && printf "%-80s ... no-build\n" "$LABEL"
            w_skipped=$((w_skipped + 1))
            continue
        fi

        local test_passed=true
        if [[ -n "$PACKAGE_PATH" ]]; then
            # SPM: swift test rebuilds incrementally, so mutation must stay in file
            # Lock remains held in SPM mode (JOBS always 1 for SPM)
            local -a spm_args=(swift test --package-path "$PACKAGE_PATH")
            [[ -n "$TEST_FILTER" ]] && spm_args+=(--filter "$TEST_CLASS")
            if "${spm_args[@]}" 2>/dev/null; then
                test_passed=true
            else
                test_passed=false
            fi
            cp "$BACKUP" "$FILE"
        else
            # xcodebuild: test-without-building uses pre-compiled DD artifacts
            # Safe to restore file and release lock — test runs on isolated DD + sim
            cp "$BACKUP" "$FILE"
            [[ "$JOBS" -gt 1 ]] && flock -u 9

            local -a test_args=(xcodebuild test-without-building -scheme "$SCHEME" -destination "$W_DEST" -quiet)
            [[ -n "$W_DD" ]] && test_args+=(-derivedDataPath "$W_DD")
            [[ -n "$TEST_FILTER" ]] && test_args+=($TEST_FILTER)
            if "${test_args[@]}" 2>/dev/null; then
                test_passed=true
            else
                test_passed=false
            fi
        fi

        if [[ "$test_passed" == "true" ]]; then
            [[ "$QUIET" == "false" ]] && printf "%-80s ... SURVIVED\n" "$LABEL"
            w_survived_lines="${w_survived_lines}line ${MUT_LINE}, col ${MUT_COL}: ${MUT_OP} → ${MUT_NEWOP} — ${MUT_TYPE}\n"
        else
            [[ "$QUIET" == "false" ]] && printf "%-80s ... killed\n" "$LABEL"
            w_killed=$((w_killed + 1))
        fi
    done

    # Write results to file (atomic)
    printf "%d\n%d\n%b" "$w_killed" "$w_skipped" "$w_survived_lines" > "$W_RESULT"
}

# ── Clone simulators + per-worker DerivedData (xcodebuild, JOBS > 1) ─────────
declare -a WORKER_DD_PATHS=()
if [[ "$JOBS" -gt 1 && -z "$PACKAGE_PATH" && -n "$SIM_UDID" ]]; then
    # Cap JOBS to TOTAL mutations
    [[ "$JOBS" -gt "$TOTAL" ]] && JOBS="$TOTAL"

    printf "Setting up %d parallel workers... " "$JOBS"
    for j in $(seq 2 "$JOBS"); do
        CLONE_NAME="mtest-worker-${j}-$$"
        CLONE_UDID=$(xcrun simctl clone "$SIM_UDID" "$CLONE_NAME" 2>/dev/null)
        if [[ -n "$CLONE_UDID" ]]; then
            CLONED_SIM_UDIDS+=("$CLONE_UDID")
            xcrun simctl boot "$CLONE_UDID" 2>/dev/null || true
        else
            # Clone failed — reduce parallelism
            JOBS=$((j - 1))
            break
        fi
    done

    # Create per-worker DerivedData copies from initial build
    if [[ -n "$DD_BASE" ]]; then
        WORKER_DD_PATHS+=("$DD_BASE")
        for j in $(seq 1 $((${#CLONED_SIM_UDIDS[@]}))); do
            W_DD="${DD_BASE}-worker-${j}"
            cp -R "$DD_BASE" "$W_DD" 2>/dev/null || true
            WORKER_DD_PATHS+=("$W_DD")
        done
    fi
    echo "done ($JOBS workers)"
fi

# ── Mutation loop ─────────────────────────────────────────────────────────────
if [[ "$QUIET" == "false" ]]; then
    echo ""
    echo "Running $TOTAL mutations:"
    echo ""
fi

if [[ "$JOBS" -le 1 ]]; then
    # ── Sequential mode ──────────────────────────────────────────────────────
    RESULT_FILE="/tmp/mtest-worker-$$-0.result"
    run_mutation_worker 0 0 "$TOTAL" "$DESTINATION" "$RESULT_FILE" "${DD_BASE:-}"
else
    # ── Parallel mode ────────────────────────────────────────────────────────
    # Build destination list: primary simulator + cloned ones
    declare -a SIM_DESTS=()
    SIM_DESTS+=("$DESTINATION")
    for cid in "${CLONED_SIM_UDIDS[@]}"; do
        SIM_DESTS+=("platform=iOS Simulator,id=$cid")
    done

    # Distribute mutations into chunks
    CHUNK_SIZE=$(( (TOTAL + JOBS - 1) / JOBS ))
    declare -a WORKER_PIDS=()

    for j in $(seq 0 $((JOBS - 1))); do
        W_START=$((j * CHUNK_SIZE))
        W_END=$(( (j + 1) * CHUNK_SIZE ))
        [[ "$W_END" -gt "$TOTAL" ]] && W_END="$TOTAL"
        [[ "$W_START" -ge "$TOTAL" ]] && break

        W_DEST="${SIM_DESTS[$j]}"
        W_RESULT="/tmp/mtest-worker-$$-${j}.result"
        W_DD="${WORKER_DD_PATHS[$j]:-}"

        run_mutation_worker "$j" "$W_START" "$W_END" "$W_DEST" "$W_RESULT" "$W_DD" &
        WORKER_PIDS+=($!)
    done

    # Wait for all workers
    for pid in "${WORKER_PIDS[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
fi

# ── Result aggregation ───────────────────────────────────────────────────────
KILLED=0
SKIPPED=0
declare -a SURVIVED_LIST=()

for rfile in /tmp/mtest-worker-$$-*.result; do
    [[ -f "$rfile" ]] || continue
    W_KILLED=$(sed -n '1p' "$rfile")
    W_SKIPPED=$(sed -n '2p' "$rfile")
    W_SURVIVED=$(sed -n '3,$p' "$rfile")

    KILLED=$((KILLED + W_KILLED))
    SKIPPED=$((SKIPPED + W_SKIPPED))
    while IFS= read -r line; do
        [[ -n "$line" ]] && SURVIVED_LIST+=("$line")
    done <<< "$W_SURVIVED"
done

# ── Report ────────────────────────────────────────────────────────────────────
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
SURVIVED_COUNT=$((TOTAL - KILLED - SKIPPED))

echo ""
echo "Results:"
printf "  Total mutations:        %d\n" "$TOTAL"
printf "  Killed (caught):        %d\n" "$KILLED"
printf "  Survived (missed):      %d\n" "$SURVIVED_COUNT"
[[ "$SKIPPED" -gt 0 ]] && printf "  Skipped (no-build):     %d\n" "$SKIPPED"

if [[ "${#SURVIVED_LIST[@]}" -gt 0 ]]; then
    echo ""
    echo "Survived mutations (untested behaviors):"
    for item in "${SURVIVED_LIST[@]}"; do
        echo "  - $item"
    done
    echo ""
    echo "Each survived mutation represents a missing test scenario."
    echo "Add G/W/T scenarios that exercise these behaviors."
fi

TESTED=$((KILLED + SURVIVED_COUNT))
if [[ "$TESTED" -eq 0 ]]; then
    echo ""
    echo "Mutation score: N/A — all mutations caused compile errors"
    printf "  Duration: %dm %ds\n" $((ELAPSED / 60)) $((ELAPSED % 60))
    exit 0
fi

SCORE=$(python3 -c "print(int($KILLED / $TESTED * 100))")
echo ""
if [[ "$SCORE" -ge "$THRESHOLD" ]]; then
    echo "Mutation score: ${SCORE}% [PASS — threshold: ${THRESHOLD}%]"
else
    echo "Mutation score: ${SCORE}% [FAIL — below threshold: ${THRESHOLD}%]"
fi

# ── Performance summary ──────────────────────────────────────────────────────
echo ""
echo "Performance:"
printf "  Duration:    %dm %ds\n" $((ELAPSED / 60)) $((ELAPSED % 60))
if [[ "$TOTAL" -gt 0 ]]; then
    AVG_SEC=$((ELAPSED / TOTAL))
    printf "  Avg/mutation: %ds\n" "$AVG_SEC"
fi
printf "  Workers:     %d\n" "$JOBS"
OPTS=""
[[ -n "$TEST_FILE" ]] && OPTS="${OPTS}single-test "
[[ -n "$GIT_DIFF_BASE" ]] && OPTS="${OPTS}git-diff "
[[ -n "$SIM_UDID" ]] && OPTS="${OPTS}pre-boot "
[[ "$JOBS" -gt 1 ]] && OPTS="${OPTS}parallel "
[[ "$QUIET" == "true" ]] && OPTS="${OPTS}quiet "
[[ -z "$OPTS" ]] && OPTS="none"
printf "  Optimizations: %s\n" "$OPTS"

if [[ "$SCORE" -ge "$THRESHOLD" ]]; then
    exit 0
else
    exit 1
fi
