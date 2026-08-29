#!/usr/bin/env bash
# shutdown-nudge.sh — a weekday end-of-day notification reminding you to run /perma-shutdown,
# so the day's open loops land in Permanence instead of coming home with you. Opt-in scaffolding for
# the /perma-shutdown ritual; the ritual is the point, this just remembers it for you.
#
#   (no args)          fire the notification now — this is what the scheduled task runs
#   --install [HH:MM]  install/reload the Mon–Fri schedule (default 17:00)
#   --uninstall        remove it
#
# Notification backend is per-OS (macOS: osascript, Linux: notify-send if present, Windows: msg.exe
# via Git Bash) and degrades to a log line if no native notifier is available — the schedule is the
# load-bearing part; the popup is a nice-to-have.
set -uo pipefail
PERMA="${PERMA_DIR:-$HOME/permanence}"
LABEL="perma-shutdown-nudge"
SELF="$PERMA/runtime/shutdown-nudge.sh"

notify() {
  local msg="Run /perma-shutdown to get today's open loops into Permanence before you stop."
  case "$(uname -s)" in
    Darwin)
      osascript -e "display notification \"$msg\" with title \"🧠 Wind-down\" sound name \"Glass\"" 2>/dev/null && return ;;
    Linux)
      if command -v notify-send >/dev/null 2>&1; then
        notify-send "🧠 Wind-down" "$msg" 2>/dev/null && return
      fi ;;
    MINGW*|MSYS*|CYGWIN*)
      command -v msg.exe >/dev/null 2>&1 && msg.exe "$(whoami)" "$msg" 2>/dev/null && return ;;
  esac
  echo "[$(date '+%Y-%m-%d %H:%M')] wind-down nudge: $msg" >> "$PERMA/runtime/logs/shutdown-nudge.log"
}

case "${1:-notify}" in
  --install)
    when="${2:-17:00}"
    mkdir -p "$PERMA/runtime/logs"
    source "$PERMA/runtime/schedule-task.sh"
    schedule_task "$LABEL" "$SELF" "weekdays $when"
    ;;
  --uninstall)
    source "$PERMA/runtime/schedule-task.sh"
    unschedule_task "$LABEL"
    ;;
  *) notify ;;
esac
