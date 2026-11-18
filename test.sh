#!/bin/bash
# Self-check for the formatting step of lint-gate.sh. Needs ruff and oxlint.
# Run: bash ~/.claude/skills/commit-gate/test.sh

set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO=$(mktemp -d)
trap 'rm -rf "$REPO"' EXIT
cd "$REPO" || exit 1
git init -q
mkdir -p scripts web/node_modules/.bin
cp "$SKILL_DIR/lint-gate.sh" scripts/
chmod +x scripts/lint-gate.sh
touch scripts/lint-gate.conf
# Stub prettier: proves it runs from web/ with a path relative to it
# shellcheck disable=SC2016 # expands inside the stub
printf '#!/bin/sh\n[ "$(basename "$PWD")" = web ] && [ "$4" = "a.js" ] && echo "export const a = 1" >"$4"\n' \
	>web/node_modules/.bin/prettier
chmod +x web/node_modules/.bin/prettier
echo 'web/node_modules/' >.gitignore

fail=0
expect() { # expect <description> <command...>
	local what=$1
	shift
	if "$@"; then echo "ok   - $what"; else
		echo "FAIL - $what"
		fail=1
	fi
}

printf 'x   =   1\n' >a.py
printf 'export   const a=1\n' >web/a.js
git add .gitignore scripts a.py web/a.js
expect "run passes" bash -c 'scripts/lint-gate.sh run >run.log'
expect "staged python is formatted" test "$(git show :a.py)" = "x = 1"
expect "staged js went through the project's prettier" test "$(git show :web/a.js)" = "export const a = 1"
expect "check matches the formatted tree" scripts/lint-gate.sh check

printf 'y   =   2\n' >b.py
git add b.py
echo 'z = 3' >>b.py
expect "partially staged file blocks" bash -c '! scripts/lint-gate.sh run >/dev/null'
expect "partially staged file is left alone" test "$(git show :b.py)" = "y   =   2"

((fail)) && cat run.log
exit $fail
