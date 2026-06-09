#!/bin/bash
# crap-score.sh — CRAP score calculator for Swift functions
# Formula: CRAP = CC * (1 - coverage)²
# Requires: lizard (pip install lizard), xcrun xccov (built-in Xcode)
# Usage: bash .claude/tools/crap-score.sh --file <path> --xcresult <path> [--threshold <number>]

set -uo pipefail

FILE=""
XCRESULT=""
THRESHOLD=30

while [[ $# -gt 0 ]]; do
    case $1 in
        --file) FILE="$2"; shift 2 ;;
        --xcresult) XCRESULT="$2"; shift 2 ;;
        --threshold) THRESHOLD="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [ -z "$FILE" ] || [ -z "$XCRESULT" ]; then
    echo "Usage: crap-score.sh --file <swift-file> --xcresult <path.xcresult> [--threshold <number>]"
    exit 1
fi

if [ ! -f "$FILE" ]; then
    echo "Error: File not found: $FILE"
    exit 1
fi

if ! command -v lizard &>/dev/null; then
    echo "Error: lizard not found. Install with: pip install lizard"
    exit 1
fi

FILENAME=$(basename "$FILE")

echo ""
echo "CRAP Analysis: $FILE"
echo "Threshold: CRAP > $THRESHOLD = DECRAP required"
echo ""

# Get coverage data per function from xccov
if ! COVERAGE_JSON=$(xcrun xccov view --report --json "$XCRESULT" 2>/dev/null); then
    echo "Error: Cannot read coverage from $XCRESULT"
    echo "Run tests first: xcodebuild test -scheme <scheme> -enableCodeCoverage YES -resultBundlePath ./build.xcresult"
    exit 1
fi

# Parse cyclomatic complexity from lizard (CSV output)
LIZARD_OUTPUT=$(lizard "$FILE" -l swift --csv 2>/dev/null | tail -n +2)

if [ -z "$LIZARD_OUTPUT" ]; then
    echo "No functions found in $FILE (or lizard could not parse it)"
    exit 0
fi

printf "%-50s %-8s %-6s %-10s %-12s\n" "Function" "Line" "CC" "Coverage" "CRAP"
printf "%-50s %-8s %-6s %-10s %-12s\n" "--------" "----" "--" "--------" "----"

NEEDS_DECRAP=0

while IFS=',' read -r nloc cc token param length location long_name _rest; do
    func_line=$(echo "$location" | sed 's/.*://')
    func_name=$(echo "$long_name" | sed 's/@.*//' | xargs)

    # Find lineCoverage for this function from xccov JSON
    coverage=$(echo "$COVERAGE_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
target_file = '$FILENAME'
try:
    func_line = int('$func_line')
except:
    func_line = 0
for target in data.get('targets', []):
    for f in target.get('files', []):
        if target_file in f.get('name', ''):
            for func in f.get('functions', []):
                if abs(func.get('lineNumber', 0) - func_line) <= 3:
                    print(func.get('lineCoverage', 0))
                    sys.exit(0)
print(0)
" 2>/dev/null || echo "0")

    # Calculate CRAP = CC * (1 - coverage)²
    crap=$(python3 -c "
cc = int('$cc') if '$cc'.isdigit() else 1
cov = float('$coverage')
crap = cc * (1 - cov) ** 2
print(f'{crap:.1f}')
" 2>/dev/null || echo "N/A")

    verdict="OK"
    if python3 -c "
import sys
try:
    sys.exit(0 if float('$crap') <= $THRESHOLD else 1)
except:
    sys.exit(0)
" 2>/dev/null; then
        verdict="OK"
    else
        verdict="DECRAP"
        NEEDS_DECRAP=1
    fi

    coverage_pct=$(python3 -c "print(f'{float(\"$coverage\")*100:.0f}%')" 2>/dev/null || echo "N/A")
    printf "%-50s %-8s %-6s %-10s %-12s\n" "${func_name:0:50}" "$func_line" "$cc" "$coverage_pct" "$crap [$verdict]"

done <<< "$LIZARD_OUTPUT"

echo ""
if [ "$NEEDS_DECRAP" -eq 1 ]; then
    echo "DECRAP required for flagged functions:"
    echo "  - If CC > 10: extract methods to reduce cyclomatic complexity"
    echo "  - If coverage < 50%: write tests for uncovered branches"
    exit 1
else
    echo "All functions within CRAP threshold ($THRESHOLD). No DECRAP needed."
fi
