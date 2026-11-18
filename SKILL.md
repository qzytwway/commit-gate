---
name: commit-gate
description: Set up a commit gate in the current git repository so every commit Claude makes is first auto-formatted, must pass lint on every language in the project (detected automatically at each commit) and then an independent Fable 5.2 review of the staged diff. Use when the user asks to add, install or configure the lint gate, commit gate, commit review, "lint + Fable review before commit", or to copy this commit flow to another project.
---

# Commit gate

Installs two PreToolUse hooks on `Bash(git commit*)` in the project's `.claude/settings.json`:

1. **Lint check**: blocks the commit unless `scripts/lint-gate.sh run` passed for exactly what is staged now.
2. **Fable 5.2 review**: an agent hook reads `.lint-gate/staged.diff` and rejects the commit if it finds bugs.

`scripts/lint-gate.sh run` first formats the **staged** files and restages them: gofmt (Go),
ruff format (Python), and for JS/TS the project's own prettier (the nearest
`node_modules/.bin/prettier`, so its config and plugins apply; JS/TS is left as is when
there is none). A staged file that also has unstaged edits blocks, since restaging it would
pull those edits in. This replaces a git pre-commit hook that only formats: the project
doesn't need one.

It then lints the **whole project**, not just the diff. At every run it
looks at the extensions of all tracked files and runs the built-in linter for each language
found: golangci-lint (Go), ruff (Python), cargo clippy (Rust), oxlint with React rules (JS/TS), shellcheck
(shell). It blocks when a linter fails, when a needed linter is not installed, or when a file
type is neither a known language nor on its non-code list, so a language added later is never
skipped silently. It gates only commits made by Claude, not the user's own terminal commits.

## Steps

1. Confirm the working directory is a git repository.
2. Run, from the repository root: `bash ~/.claude/skills/commit-gate/setup.sh`
   It writes `scripts/lint-gate.sh`, creates `scripts/lint-gate.conf` if missing, merges the
   hooks into `.claude/settings.json` and adds `.lint-gate/` to `.gitignore`. Re-running
   updates the script and hooks and keeps the conf.
3. Leave `scripts/lint-gate.conf` empty. Every project uses the same built-in linters, so do
   not put the project's own lint command (Makefile `lint` target, `package.json` lint
   script, ...) in `LINT_CMD`, and never list a built-in language in `COVERED`. `LINT_CMD`
   and `COVERED` exist only for file types the gate has no built-in linter for.
4. Add this to the project's `CLAUDE.md` (create it if missing; replace an older copy):

   ```markdown
   ## Committing

   Stage the files, run `scripts/lint-gate.sh run`, then `git commit`. The script formats the
   staged files and restages them (gofmt, ruff format, the project's own prettier for JS/TS),
   then lints the whole project with its built-in linter for every language it finds in the tracked files,
   whatever lint setup the project has of its own. On success it records the staged tree and saves the staged diff
   in `.lint-gate/`. PreToolUse hooks in `.claude/settings.json` on `Bash(git commit*)` block
   the commit unless that record matches what is staged, and an independent Fable 5.2 agent
   reviews the saved diff and rejects the commit if it finds bugs. Restaging anything voids
   the record, so rerun the script. Stage whole files: a file with unstaged edits left over
   blocks the run. When it reports a missing linter, ask the user before
   installing it. When it reports a file type with no linter, add a command for it to
   `LINT_CMD` and the extension to `COVERED` in `scripts/lint-gate.conf`, or, only if it is
   not code, the extension to `NOT_CODE`. When blocked, fix
   the code and start over; don't disable rules, commit with `-a`, or work around the hooks.
   Write files with the edit tools rather than heredocs in Bash: the hooks' command matcher
   can mistake a heredoc command for a commit.
   ```

5. Run `scripts/lint-gate.sh run` once and report the result to the user in plain words:
   - **Missing linters**: list them with the install commands it printed and ask before
     installing anything (they are global installs).
   - **Unsupported file types**: say which, and propose a linter for each (or, if they are
     not code, adding the extension to `NOT_CODE`).
   - **Lint failures in existing code**: say how many and where. Until they are fixed no
     commit can pass, including the commit of the gate's own files, so ask whether to fix
     them now.
6. Tell the user: the new files (`scripts/lint-gate.sh`, `scripts/lint-gate.conf`,
   `.claude/settings.json`, `.gitignore`, `CLAUDE.md`) still need committing; hook changes
   may only take effect in a new Claude Code session; and the gate does not cover their own
   terminal commits.
