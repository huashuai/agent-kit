# Notes for coding agents

## Before you change code

1. Read [LESSONS.md](LESSONS.md): what recent work got wrong and the rule
   that would have caught it.
2. Write and check your change against the
   [code standards](docs/code-standards.md).

## Commands

<!-- Fill these in for this repo. Agents run exactly these. -->

- Build: `<build command>`
- Test: `<test command>`
- Lint / format: `<lint command>`

## Working alongside other agents

- Work in a worktree of your own (`git worktree add --detach ../wt-<name>`),
  never in a checkout another session uses. After committing,
  `git show --stat HEAD` must list your files and only yours.
- Before fixing a failing test or a bug, `git fetch` and check
  `git log origin/main` for a commit that already fixes it.

## Commit messages

A commit's subject says what changed for the user. A commit over ~100 lines
has a body: what changed, why, what was run (and what it printed), and what
wasn't tried. The nightly review reads these bodies; a commit without one
can't be checked afterwards.

## LESSONS.md

A nightly agent writes LESSONS.md. Don't edit it while doing other work,
and never edit its first line.
