#!/bin/bash
# Install the commit gate into the current git repository. Run from inside the target repo.
# Re-running is safe: it updates the script and the hook entry, and keeps scripts/lint-gate.conf.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$(git rev-parse --show-toplevel)"

mkdir -p scripts .claude
cp "$SKILL_DIR/lint-gate.sh" scripts/lint-gate.sh
chmod +x scripts/lint-gate.sh
[[ -f scripts/lint-gate.conf ]] || cp "$SKILL_DIR/lint-gate.conf" scripts/lint-gate.conf

# Merge the PreToolUse hook entry into .claude/settings.json, dropping any older copy of it
SETTINGS=.claude/settings.json
[[ -f "$SETTINGS" ]] || echo '{}' >"$SETTINGS"
jq --slurpfile entry "$SKILL_DIR/hooks.json" '
	.hooks.PreToolUse = (
		[(.hooks.PreToolUse // [])[]
			| select([.hooks[]?.command // "" | contains("lint-gate.sh check")] | any | not)]
		+ $entry)
' "$SETTINGS" >"$SETTINGS.tmp"
mv "$SETTINGS.tmp" "$SETTINGS"

# Keep the gate record out of git
grep -qxF '.lint-gate/' .gitignore 2>/dev/null || echo '.lint-gate/' >>.gitignore

echo "✅ Commit gate installed. Project settings: scripts/lint-gate.conf"
