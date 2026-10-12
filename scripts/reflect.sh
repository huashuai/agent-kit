#!/usr/bin/env bash
# Nightly reflect: an agent reviews the commits since the last review and
# updates LESSONS.md (and docs/code-standards.md when a lesson graduates).
#
# Usage: scripts/reflect.sh [repo-path]
#
# Environment (all optional):
#   REFLECT_BRANCH  branch to review and update       (default: main)
#   REFLECT_PUSH    pr | main | none                  (default: pr)
#                     pr   push a reflect/<date> branch and open a PR (needs gh)
#                     main push the commit straight to REFLECT_BRANCH
#                     none leave a local reflect/<date> branch
#   REFLECT_SINCE   window for the first run, before any review exists
#                                                     (default: "7 days ago")
#   REFLECT_MODEL   model for claude, e.g. opus       (default: claude's own)
#   REFLECT_MAX_TURNS                                 (default: 80)
set -euo pipefail

REPO="${1:-$(git rev-parse --show-toplevel)}"
BRANCH="${REFLECT_BRANCH:-main}"
PUSH="${REFLECT_PUSH:-pr}"
SINCE="${REFLECT_SINCE:-7 days ago}"
MAX_TURNS="${REFLECT_MAX_TURNS:-80}"
TODAY="$(date +%F)"

cd "$REPO"
log() { printf '%s reflect: %s\n' "$(date '+%F %T')" "$*"; }

# One run at a time per repo.
LOCK="$(git rev-parse --path-format=absolute --git-common-dir)/reflect.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  log "another run holds $LOCK; exiting"; exit 0
fi
WT=""
cleanup() {
  [ -n "$WT" ] && git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1 || true
  rmdir "$LOCK" 2>/dev/null || true
}
trap cleanup EXIT

git fetch -q origin "$BRANCH"
HEAD_SHA="$(git rev-parse "origin/$BRANCH")"

# Where did the last review stop? Read it from the branch, not the checkout.
LAST="$(git show "origin/$BRANCH:LESSONS.md" 2>/dev/null | head -1 \
  | sed -n 's/.*reviewed-through: \([0-9a-f]\{7,40\}\).*/\1/p')"

if [ -n "$LAST" ] && git merge-base --is-ancestor "$LAST" "$HEAD_SHA" 2>/dev/null; then
  RANGE="$LAST..$HEAD_SHA"
else
  BASE="$(git rev-list -1 --before="$SINCE" "$HEAD_SHA" || true)"
  if [ -n "$BASE" ]; then RANGE="$BASE..$HEAD_SHA"; else RANGE="$HEAD_SHA"; fi
fi

# Leave out the review's own commits.
COUNT="$(git rev-list --count --invert-grep --grep='^lessons: ' "$RANGE")"
if [ "$COUNT" -eq 0 ]; then
  log "nothing new in $RANGE"; exit 0
fi
log "reviewing $COUNT commits in $RANGE"

# Work in a throwaway worktree so a checkout in use is never touched.
WT="$(mktemp -d "${TMPDIR:-/tmp}/reflect.XXXXXX")"
rmdir "$WT"
git worktree add -q --detach "$WT" "$HEAD_SHA"
cd "$WT"

PROMPT_FILE="$WT/scripts/reflect-prompt.md"
[ -f "$PROMPT_FILE" ] || PROMPT_FILE="$(dirname "$0")/reflect-prompt.md"
PROMPT="$(cat "$PROMPT_FILE")"
PROMPT="${PROMPT//\{\{TODAY\}\}/$TODAY}"
PROMPT="${PROMPT//\{\{RANGE\}\}/$RANGE}"
PROMPT="${PROMPT//\{\{COUNT\}\}/$COUNT}"

SUMMARY="$(mktemp)"
# The agent may read anything and edit files; its shell is limited to
# read-only git and gh. The script, not the agent, commits.
claude -p "$PROMPT" \
  ${REFLECT_MODEL:+--model "$REFLECT_MODEL"} \
  --max-turns "$MAX_TURNS" \
  --permission-mode acceptEdits \
  --permission-prompts none \
  --allowedTools "Read" "Edit" "Write" "Grep" "Glob" \
    "Bash(git log *)" "Bash(git show *)" "Bash(git diff *)" \
    "Bash(git rev-list *)" "Bash(git blame *)" \
    "Bash(gh pr view *)" "Bash(gh pr list *)" \
    "Bash(gh issue view *)" "Bash(gh issue list *)" \
  > "$SUMMARY"

# Only LESSONS.md and the code standards may change.
STRAY="$(git status --porcelain | grep -v -E ' (LESSONS\.md|docs/code-standards\.md)$' || true)"
if [ -n "$STRAY" ]; then
  log "agent changed files it shouldn't have; discarding them:"; echo "$STRAY"
  git status --porcelain | awk '{print $2}' \
    | grep -v -E '^(LESSONS\.md|docs/code-standards\.md)$' \
    | while read -r f; do git checkout -q -- "$f" 2>/dev/null || rm -rf -- "$f"; done
fi

# The script records how far this review went, so the next one starts there.
STAMP="$(git log -1 --format=%ad --date=format:'%Y-%m-%d %H:%M %z' "$HEAD_SHA")"
HEADER="<!-- reviewed-through: ${HEAD_SHA:0:12} ($STAMP) -->"
if head -1 LESSONS.md | grep -q 'reviewed-through:'; then
  { echo "$HEADER"; tail -n +2 LESSONS.md; } > LESSONS.md.new
else
  { echo "$HEADER"; cat LESSONS.md; } > LESSONS.md.new
fi
mv LESSONS.md.new LESSONS.md

git add LESSONS.md docs/code-standards.md 2>/dev/null || git add LESSONS.md
{
  echo "lessons: review of $TODAY ($COUNT commits, ${RANGE})"
  echo
  cat "$SUMMARY"
} | git commit -q -F -
rm -f "$SUMMARY"

LOCAL_BRANCH="reflect/$TODAY-$(date +%H%M%S)"
git branch -q "$LOCAL_BRANCH" HEAD

case "$PUSH" in
  main)
    if ! git push -q origin "HEAD:$BRANCH"; then
      git fetch -q origin "$BRANCH" && git rebase -q "origin/$BRANCH" \
        && git push -q origin "HEAD:$BRANCH"
    fi
    git branch -q -D "$LOCAL_BRANCH" || true
    log "pushed $(git rev-parse --short HEAD) to $BRANCH" ;;
  pr)
    git push -q origin "$LOCAL_BRANCH"
    gh pr create --base "$BRANCH" --head "$LOCAL_BRANCH" \
      --title "lessons: review of $TODAY" \
      --body "$(git log -1 --format=%b)"
    log "opened a PR from $LOCAL_BRANCH" ;;
  none)
    log "committed on local branch $LOCAL_BRANCH" ;;
  *)
    log "unknown REFLECT_PUSH=$PUSH; left the commit on $LOCAL_BRANCH" ;;
esac
