#!/bin/bash
# Bootstrap script — downloads the /harness-init skill from ios-harnessing-hub into the current repo.
#
# Usage:
#   ./init_harness.sh [--branch <branch>]
#
# After running this, open Claude Code and run: /harness-init

set -e

BRANCH="main"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch)
      BRANCH="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: ./init_harness.sh [--branch <branch>]"
      exit 1
      ;;
  esac
done

SKILL_DIR=".claude/skills/harness-init"
SKILL_PATH="$SKILL_DIR/SKILL.md"

echo "Downloading harness-init skill from ios-harnessing-hub@${BRANCH}..."

if printf '' | base64 -d > /dev/null 2>&1; then
  BASE64_DECODE_FLAG="-d"
elif printf '' | base64 -D > /dev/null 2>&1; then
  BASE64_DECODE_FLAG="-D"
else
  echo "Error: could not determine a supported base64 decode flag for this system."
  exit 1
fi

mkdir -p "$SKILL_DIR"

gh api "repos/tcp-software/ios-harnessing-hub/contents/templates/repo-template/.claude/skills/harness-init/SKILL.md?ref=${BRANCH}" \
  --jq '.content' | base64 "$BASE64_DECODE_FLAG" > "$SKILL_PATH"

echo ""
echo "✅ Done. harness-init skill installed at: $SKILL_PATH"
echo ""
echo "Next step — open Claude Code in this repo and run:"
echo "  /harness-init"
echo ""
echo "This will pull the full harness template (.claude/, .harness/, CLAUDE.md) from ios-harnessing-hub@${BRANCH}."
