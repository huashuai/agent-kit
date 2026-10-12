# Code standards

A reviewer, human or agent, checks each of these. A change that misses one
gets a comment naming it. Rules here start small and grow: a lesson in
[LESSONS.md](../LESSONS.md) seen on 3 separate days moves into this file,
with its evidence.

## What a change contains

| Rule | What a reviewer looks at |
| --- | --- |
| A change does only what its goal needs. | Every change in behavior has a reason. Unrelated refactors and extra features go in their own change. |
| A fix reaches every sibling of the bug. | Search for the same pattern elsewhere (other callers, other platforms, other branches of the same operation) and fix them in the same change. |
| A change holds on the whole path. | Follow it from the user's input to the end result, through callers and saved state. One correct function doesn't make the operation correct. |

## Tests

| Rule | What a reviewer looks at |
| --- | --- |
| A fix comes with a test that fails without it. | Put the old code back and run the test: it must fail and name the behavior. Say what it failed with. |
| Tests check behavior, not implementation. | Assert what the user or caller needs, with realistic inputs including empty and missing values. |
| A failing test on `main` is a bug to fix now. | "Fails the same on main" is not a baseline. Fix it at its cause, or open an issue naming the cause, before shipping on top of it. |
| Tests stay out of the real machine. | No test reads or writes real user config, credentials or services. |

## Acceptance criteria

A change is merged only when it shows each of these. Say in the commit or
PR which ones were run and what they printed. A check that wasn't run is
listed as not run, never left out.

1. **A test that fails without the change**, and passes with it.
2. **The build, lint and full test suite** (commands in
   [AGENTS.md](../AGENTS.md#commands)), run on the change merged onto
   current `main`.
3. **Real use where possible.** Run the thing the way a user would. If that
   isn't possible, say so; what wasn't tried isn't told to users as working.

## Rules moved from LESSONS.md

<!-- The nightly review adds rows here when a lesson is seen on 3 days. -->

| Rule | Evidence |
| --- | --- |
