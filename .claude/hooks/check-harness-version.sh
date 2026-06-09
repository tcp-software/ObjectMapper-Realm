#!/bin/bash
# Harness version check — runs at SessionStart via .claude/settings.json
# Outputs additionalContext JSON if skills are outdated; silent otherwise.

LOCAL=$(grep '^harness_version:' .harness/VERSIONING.md 2>/dev/null | awk '{print $2}')
LATEST=$(gh api repos/tcp-software/ios-harnessing-hub/releases/latest --jq '.tag_name' 2>/dev/null)

# Silent exit if data unavailable (repo has no VERSIONING.md, or gh not authed)
if [ -z "$LOCAL" ] || [ -z "$LATEST" ]; then
  exit 0
fi

# Silent exit if up to date
if [ "$LOCAL" = "$LATEST" ]; then
  exit 0
fi

# Inject warning into Claude's context as a system reminder
echo "{\"additionalContext\": \"⚠️ Harness skills outdated — installed: $LOCAL, latest: $LATEST. Run /harness-sync to update.\"}"
