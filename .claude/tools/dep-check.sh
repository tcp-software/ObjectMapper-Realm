#!/bin/bash
# dep-check.sh — Swift dependency boundary checker
# Checks Swift imports using heuristic CleanSwift layer rules (filename-based).
# Optionally accepts --architecture to reference the project architecture file,
# but layer detection is based on filename patterns, not file content.
# Usage: bash .claude/tools/dep-check.sh [--architecture <path>]

set -uo pipefail

ARCHITECTURE_FILE=".harness/ARCHITECTURE.md"

while [[ $# -gt 0 ]]; do
    case $1 in
        --architecture) ARCHITECTURE_FILE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

echo ""
echo "Dependency Boundary Check"

# Prefer changed files (git diff), fall back to all Swift files
if git diff --name-only main -- '*.swift' 2>/dev/null | grep -q '.'; then
    echo "Scope: Swift files changed since main"
    SWIFT_FILES=$(git diff --name-only main -- '*.swift' 2>/dev/null)
else
    echo "Scope: all Swift files in project"
    SWIFT_FILES=$(find . -name "*.swift" \
        -not -path "*/build/*" \
        -not -path "*/.build/*" \
        -not -path "*/DerivedData/*" \
        2>/dev/null)
fi

if [ -n "$ARCHITECTURE_FILE" ] && [ -f "$ARCHITECTURE_FILE" ]; then
    echo "Architecture: $ARCHITECTURE_FILE (reference only — checks are heuristic filename-based)"
else
    echo "Note: $ARCHITECTURE_FILE not found — proceeding with heuristic CleanSwift layer rules"
fi

echo ""

BLOCKS=0
WARNINGS=0

while IFS= read -r file; do
    [ -f "$file" ] || continue

    # Determine layer from file/directory naming (CleanSwift convention)
    LAYER="Unknown"
    if echo "$file" | grep -qiE "ViewController|View\.swift"; then
        LAYER="View"
    elif echo "$file" | grep -qi "Presenter"; then
        LAYER="Presenter"
    elif echo "$file" | grep -qi "Interactor"; then
        LAYER="Interactor"
    elif echo "$file" | grep -qi "Worker"; then
        LAYER="Worker"
    elif echo "$file" | grep -qi "Router"; then
        LAYER="Router"
    elif echo "$file" | grep -qiE "Service|Repository|Manager"; then
        LAYER="Service"
    fi

    # Get all import lines with line numbers
    while IFS=: read -r line_num import_stmt; do
        MODULE=$(echo "$import_stmt" | sed 's/^import //' | xargs)

        VIOLATION=""
        SEVERITY=""

        # CleanSwift layer violation rules
        if [ "$LAYER" = "View" ]; then
            if echo "$MODULE" | grep -qiE "Service|Repository|Worker|Manager"; then
                VIOLATION="View layer must not import Service/Worker/Repository modules — route through Interactor/Presenter"
                SEVERITY="BLOCK"
            fi
        fi

        if [ "$LAYER" = "Presenter" ]; then
            if echo "$MODULE" | grep -qiE "Service|Repository|Manager"; then
                VIOLATION="Presenter must not import Service/Repository modules — only Interactor may access services"
                SEVERITY="BLOCK"
            fi
        fi

        if [ -n "$VIOLATION" ]; then
            FILE_PATH=$(echo "$file" | sed 's|./||')
            echo "[$SEVERITY] $FILE_PATH:$line_num — import $MODULE"
            echo "         Reason: $VIOLATION"
            BLOCKS=$((BLOCKS + 1))
        fi

        # Check for potentially unused imports (rough heuristic: module name appears only on import line)
        USAGE_COUNT=$(grep -c "$MODULE" "$file" 2>/dev/null || echo "1")
        if [ "$USAGE_COUNT" -lt 2 ]; then
            FILE_PATH=$(echo "$file" | sed 's|./||')
            echo "[WARNING] $FILE_PATH:$line_num — import $MODULE may be unused (no other references found)"
            WARNINGS=$((WARNINGS + 1))
        fi

    done < <(grep -n "^import " "$file" 2>/dev/null || true)

done <<< "$SWIFT_FILES"

echo ""
echo "Summary:"
echo "  BLOCK:   $BLOCKS layer violation(s) — must fix before merge"
echo "  WARNING: $WARNINGS potential issue(s) — investigate"

if [ "$BLOCKS" -gt 0 ]; then
    echo ""
    echo "BLOCKED: resolve layer violations before proceeding."
    exit 1
else
    echo ""
    if [ "$WARNINGS" -eq 0 ]; then
        echo "No dependency issues detected."
    else
        echo "No layer violations. Review warnings above."
    fi
    exit 0
fi
