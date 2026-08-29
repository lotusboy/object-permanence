#!/usr/bin/env bash
# schedule-task.sh — cross-platform "install/remove a recurring background task", sourced by
# install.sh and shutdown-nudge.sh rather than duplicated. One abstraction, three backends:
#   macOS            → launchd
#   Linux (or WSL)   → cron
#   Windows (native, via Git Bash) → schtasks.exe
#
# NOTE: the Linux and Windows backends were written carefully but could not be run-tested on
# this machine (macOS) — review the crontab/schtasks syntax before relying on them, and report
# back anything that needs fixing on those platforms.
#
# Usage:
#   schedule_task LABEL COMMAND SPEC
#     SPEC: "daily HH:MM" | "weekday N HH:MM" (N=1 Mon..7 Sun) | "weekdays HH:MM" (Mon-Fri)
#   unschedule_task LABEL
#
# LABEL should be a stable, unique identifier (e.g. "perma-consolidate") — used as the launchd
# label suffix, the cron marker comment, and the schtasks task name, so re-running is idempotent
# and unschedule_task can find what to remove.

_perma_os() {
  case "$(uname -s)" in
    Darwin) echo darwin ;;
    Linux) echo linux ;;
    MINGW*|MSYS*|CYGWIN*) echo windows ;;
    *) echo unknown ;;
  esac
}

_cron_spec() {
  # SPEC -> "MIN HOUR * * DOW" (cron DOW: 0=Sun..6=Sat)
  local spec="$1" kind hhmm hh mm n dow
  kind="${spec%% *}"
  case "$kind" in
    daily)
      hhmm="${spec#daily }"; hh="${hhmm%%:*}"; mm="${hhmm##*:}"
      echo "$((10#$mm)) $((10#$hh)) * * *" ;;
    weekday)
      n="${spec#weekday }"; n="${n%% *}"; hhmm="${spec##* }"; hh="${hhmm%%:*}"; mm="${hhmm##*:}"
      dow=$(( n % 7 ))   # our 1=Mon..7=Sun -> cron 1=Mon..6=Sat,0=Sun
      echo "$((10#$mm)) $((10#$hh)) * * $dow" ;;
    weekdays)
      hhmm="${spec#weekdays }"; hh="${hhmm%%:*}"; mm="${hhmm##*:}"
      echo "$((10#$mm)) $((10#$hh)) * * 1-5" ;;
  esac
}

_schtasks_args() {
  # SPEC -> schtasks /SC ... /D ... /ST HH:MM args, printed as lines: SC, D (or empty), ST
  local spec="$1" kind hhmm hh mm n dow
  local days=(SUN MON TUE WED THU FRI SAT)
  kind="${spec%% *}"
  case "$kind" in
    daily)
      hhmm="${spec#daily }"; hh="${hhmm%%:*}"; mm="${hhmm##*:}"
      printf 'DAILY\n\n%02d:%02d\n' "$((10#$hh))" "$((10#$mm))" ;;
    weekday)
      n="${spec#weekday }"; n="${n%% *}"; hhmm="${spec##* }"; hh="${hhmm%%:*}"; mm="${hhmm##*:}"
      dow=$(( n % 7 ))
      printf 'WEEKLY\n%s\n%02d:%02d\n' "${days[$dow]}" "$((10#$hh))" "$((10#$mm))" ;;
    weekdays)
      hhmm="${spec#weekdays }"; hh="${hhmm%%:*}"; mm="${hhmm##*:}"
      printf 'WEEKLY\nMON,TUE,WED,THU,FRI\n%02d:%02d\n' "$((10#$hh))" "$((10#$mm))" ;;
  esac
}

schedule_task() {
  local label="$1" command="$2" spec="$3"
  case "$(_perma_os)" in
    darwin)
      local plist_label; plist_label="com.$(id -un).${label}"
      local plist_dst="$HOME/Library/LaunchAgents/${plist_label}.plist"
      mkdir -p "$HOME/Library/LaunchAgents"
      {
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
        echo '<plist version="1.0"><dict>'
        echo "  <key>Label</key><string>$plist_label</string>"
        echo "  <key>ProgramArguments</key><array><string>/bin/bash</string><string>-c</string><string>$command</string></array>"
        case "$spec" in
          daily\ *)
            local hhmm="${spec#daily }"
            echo "  <key>StartCalendarInterval</key><dict><key>Hour</key><integer>$((10#${hhmm%%:*}))</integer><key>Minute</key><integer>$((10#${hhmm##*:}))</integer></dict>" ;;
          weekday\ *)
            local n="${spec#weekday }"; n="${n%% *}"; local hhmm="${spec##* }"
            echo "  <key>StartCalendarInterval</key><dict><key>Weekday</key><integer>$n</integer><key>Hour</key><integer>$((10#${hhmm%%:*}))</integer><key>Minute</key><integer>$((10#${hhmm##*:}))</integer></dict>" ;;
          weekdays\ *)
            local hhmm="${spec#weekdays }"
            echo "  <key>StartCalendarInterval</key><array>"
            for d in 1 2 3 4 5; do
              echo "    <dict><key>Weekday</key><integer>$d</integer><key>Hour</key><integer>$((10#${hhmm%%:*}))</integer><key>Minute</key><integer>$((10#${hhmm##*:}))</integer></dict>"
            done
            echo "  </array>" ;;
        esac
        echo "</dict></plist>"
      } > "$plist_dst"
      launchctl bootout "gui/$(id -u)/$plist_label" 2>/dev/null
      launchctl bootstrap "gui/$(id -u)" "$plist_dst" 2>/dev/null \
        && echo "  launchd: $label scheduled ($plist_label)" \
        || echo "  launchd: WARN — $label bootstrap failed, load manually: launchctl bootstrap gui/$(id -u) $plist_dst"
      ;;
    linux)
      local cron_line marker="# $label"
      cron_line="$(_cron_spec "$spec") $command $marker"
      ( crontab -l 2>/dev/null | grep -vF "$marker"; echo "$cron_line" ) | crontab -
      if [ $? -eq 0 ]; then echo "  cron: $label scheduled"; else echo "  cron: WARN — could not install crontab entry for $label, add by hand: $cron_line"; fi
      ;;
    windows)
      local args; args="$(_schtasks_args "$spec")"
      local sc; sc="$(sed -n '1p' <<<"$args")"
      local d; d="$(sed -n '2p' <<<"$args")"
      local st; st="$(sed -n '3p' <<<"$args")"
      local bash_win
      bash_win="$(cygpath -w "$(command -v bash)" 2>/dev/null || echo bash)"
      local tr_cmd="\"$bash_win\" -lc \"$command\""
      if [ -n "$d" ]; then
        MSYS_NO_PATHCONV=1 schtasks /Create /SC "$sc" /D "$d" /ST "$st" /TN "$label" /TR "$tr_cmd" /F >/dev/null 2>&1
      else
        MSYS_NO_PATHCONV=1 schtasks /Create /SC "$sc" /ST "$st" /TN "$label" /TR "$tr_cmd" /F >/dev/null 2>&1
      fi
      if [ $? -eq 0 ]; then echo "  schtasks: $label scheduled"; else echo "  schtasks: WARN — could not create task $label, run by hand: MSYS_NO_PATHCONV=1 schtasks /Create /SC $sc ${d:+/D $d} /ST $st /TN $label /TR '$tr_cmd' /F"; fi
      ;;
    *)
      echo "  WARN — unrecognized OS ($(uname -s)); skipping scheduling for $label. Run it manually or via your own scheduler: $command"
      ;;
  esac
}

unschedule_task() {
  local label="$1"
  case "$(_perma_os)" in
    darwin)
      local plist_label; plist_label="com.$(id -un).${label}"
      launchctl bootout "gui/$(id -u)/$plist_label" 2>/dev/null || true
      rm -f "$HOME/Library/LaunchAgents/${plist_label}.plist"
      ;;
    linux)
      local marker="# $label"
      ( crontab -l 2>/dev/null | grep -vF "$marker" ) | crontab - 2>/dev/null || true
      ;;
    windows)
      MSYS_NO_PATHCONV=1 schtasks /Delete /TN "$label" /F >/dev/null 2>&1 || true
      ;;
  esac
  echo "  $label: removed"
}
