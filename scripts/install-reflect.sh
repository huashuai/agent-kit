#!/usr/bin/env bash
# Schedule scripts/reflect.sh to run once a day on this machine.
# macOS uses a launchd agent (a run missed while asleep happens on wake);
# Linux uses your crontab.
#
# Usage, from inside the repo:
#   scripts/install-reflect.sh [HH:MM]   install or replace (default 02:17)
#   scripts/install-reflect.sh --now     run once now, in the foreground
#   scripts/install-reflect.sh --uninstall
#
# REFLECT_PUSH, REFLECT_BRANCH, REFLECT_MODEL set when you install are kept
# for the scheduled runs.
set -euo pipefail

REPO="$(git rev-parse --show-toplevel)"
NAME="reflect-$(basename "$REPO" | tr -c 'A-Za-z0-9._\n-' '-')"
SCRIPT="$REPO/scripts/reflect.sh"
LOGDIR="$HOME/.local/state/reflect"
LOG="$LOGDIR/$NAME.log"
PLIST="$HOME/Library/LaunchAgents/dev.$NAME.plist"
ARG="${1:-02:17}"

uninstall() {
  if [ "$(uname)" = Darwin ]; then
    launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
  else
    crontab -l 2>/dev/null | grep -v "# $NAME\$" | crontab - || true
  fi
}

case "$ARG" in
  --uninstall) uninstall; echo "Removed the daily review for $REPO."; exit 0 ;;
  --now) exec bash "$SCRIPT" "$REPO" ;;
esac

[[ "$ARG" =~ ^([01]?[0-9]|2[0-3]):([0-5][0-9])$ ]] \
  || { echo "Time must be HH:MM, got: $ARG" >&2; exit 1; }
H=$((10#${BASH_REMATCH[1]})); M=$((10#${BASH_REMATCH[2]}))

CLAUDE="$(command -v claude)" || { echo "claude isn't on PATH." >&2; exit 1; }
[ -f "$SCRIPT" ] || { echo "Missing $SCRIPT" >&2; exit 1; }
chmod +x "$SCRIPT"
if [ "${REFLECT_PUSH:-pr}" = pr ] && ! command -v gh >/dev/null; then
  echo "REFLECT_PUSH=pr needs the gh CLI. Install gh, or set REFLECT_PUSH=main or none." >&2
  exit 1
fi
mkdir -p "$LOGDIR"

# Scheduled jobs get a bare PATH; give them the one that finds claude, git, gh.
RUN_PATH="$(dirname "$CLAUDE"):$(dirname "$(command -v git)")"
command -v gh >/dev/null && RUN_PATH="$RUN_PATH:$(dirname "$(command -v gh)")"
RUN_PATH="$RUN_PATH:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"

ENVS=(PATH="$RUN_PATH" HOME="$HOME")
for v in REFLECT_PUSH REFLECT_BRANCH REFLECT_MODEL REFLECT_SINCE CLAUDE_CODE_OAUTH_TOKEN; do
  [ -n "${!v:-}" ] && ENVS+=("$v=${!v}")
done

uninstall
if [ "$(uname)" = Darwin ]; then
  mkdir -p "$(dirname "$PLIST")"
  {
    cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>dev.$NAME</string>
  <key>ProgramArguments</key><array>
    <string>/bin/bash</string><string>$SCRIPT</string><string>$REPO</string>
  </array>
  <key>StartCalendarInterval</key><dict>
    <key>Hour</key><integer>$H</integer><key>Minute</key><integer>$M</integer>
  </dict>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
  <key>EnvironmentVariables</key><dict>
EOF
    for e in "${ENVS[@]}"; do
      printf '    <key>%s</key><string>%s</string>\n' "${e%%=*}" "${e#*=}"
    done
    echo '  </dict>'
    echo '</dict></plist>'
  } > "$PLIST"
  chmod 600 "$PLIST"
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
  WHERE="launchd ($PLIST)"
else
  LINE="$M $H * * * $(printf '%q ' "${ENVS[@]}")/bin/bash $(printf '%q' "$SCRIPT") $(printf '%q' "$REPO") >> $(printf '%q' "$LOG") 2>&1 # $NAME"
  { crontab -l 2>/dev/null || true; echo "$LINE"; } | crontab -
  WHERE="your crontab"
fi

printf 'Daily review of %s at %02d:%02d, via %s.\nLog: %s\nTry it now: scripts/install-reflect.sh --now\n' \
  "$REPO" "$H" "$M" "$WHERE" "$LOG"
