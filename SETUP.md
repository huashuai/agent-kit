# Agent kit: setup

Copy these into your repo's root (keep the paths), then delete this file.

    CLAUDE.md                    loads AGENTS.md and LESSONS.md for Claude Code
    AGENTS.md                    short rules for every agent; fill in Commands
    LESSONS.md                   written by the nightly review; starts empty
    docs/code-standards.md       what "done" means; grows from LESSONS.md
    scripts/reflect.sh           one review run
    scripts/reflect-prompt.md    what the reviewer is told to do
    scripts/install-reflect.sh   schedules reflect.sh daily (launchd or cron)

## Steps

1. Fill in the build, test and lint commands in AGENTS.md. Edit
   docs/code-standards.md to fit your stack.
2. Commit and push all of it to `main`.
3. Try one review now (it looks back 7 days the first time):

       REFLECT_PUSH=pr scripts/install-reflect.sh --now

   Read the PR it opens. Tune scripts/reflect-prompt.md if it's too noisy
   or too vague, and merge.
4. Schedule it:

       REFLECT_PUSH=pr scripts/install-reflect.sh 02:17

## Choosing REFLECT_PUSH

- `pr` (default): opens a PR each night. Merge it before the next run;
  until it's merged, the next run reviews the same commits again.
- `main`: commits straight to main. Use once you trust the reviews.
- `none`: leaves a local `reflect/<date>` branch.

## Notes

- The reviewer runs in a throwaway worktree, can only edit LESSONS.md and
  docs/code-standards.md, and its shell is limited to read-only git and gh.
  The script commits, and writes the `reviewed-through` line itself.
- Needs Claude Code v2.1.259 or later (`claude update`), plus `gh` for PR mode.
- The machine must be on at the scheduled time. macOS runs a missed job on
  wake; cron skips it.
- If scheduled runs fail to sign in, run `claude setup-token` and reinstall
  with `CLAUDE_CODE_OAUTH_TOKEN=<token>` set. That stores the token in your
  crontab or LaunchAgent plist (readable only by you).
- Logs: `~/.local/state/reflect/reflect-<repo>.log`.
- Remove: `scripts/install-reflect.sh --uninstall`.
