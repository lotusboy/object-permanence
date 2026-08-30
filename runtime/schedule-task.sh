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
#
# OWNERSHIP GUARD. The label is derived from the task name and your username, NOT from the install
# path, because the intended model is one Permanence per machine: a stable label is what makes a
# re-install replace its own job instead of accumulating duplicates. The cost of that choice is that
# a SECOND Permanence on the same machine — most often a test install — would otherwise silently
# take the first one's job and repoint it at the wrong directory, with nothing printed to say so.
# So before writing, both functions check which Permanence an existing job actually runs from, and
# leave it completely alone if it belongs to a different one. Re-installing over your own job is
# unchanged; only the cross-install case is refused, and it is refused loudly.

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

# The Permanence this call is acting for. install.sh and shutdown-nudge.sh both set PERMA before
# sourcing; PERMA_DIR is honoured too so a caller that only exported the override (as CI does) is
# still matched against the right directory rather than the default.
_perma_home() { printf '%s' "${PERMA:-${PERMA_DIR:-$HOME/permanence}}"; }

_existing_job_command() {  # <label> -> the command an already-scheduled job runs, or empty
  case "$(_perma_os)" in
    darwin)
      local f
      f="$HOME/Library/LaunchAgents/com.$(id -un).${1}.plist"
      [ -f "$f" ] || return 0
      tr -d '\n' < "$f" | sed -n 's#.*<string>-c</string><string>\(.*\)</string></array>.*#\1#p'
      ;;
    linux)
      crontab -l 2>/dev/null | grep -F "# ${1}" | head -1 ;;
    windows)
      MSYS_NO_PATHCONV=1 schtasks /Query /TN "$1" /FO LIST /V 2>/dev/null \
        | sed -n 's/^Task To Run: *//p' | head -1 ;;
  esac
}

# Returns 0 (and prints nothing) when it is safe to act: either no job exists, or the one that does
# belongs to this same Permanence. Returns 1 after explaining, when it belongs to another.
#   $2 = "remove", or the command this install would schedule.
_perma_owns_job() {  # <label> <command-or-"remove">
  local label="$1" intent="$2" home existing existing_bare
  home="$(_perma_home)"
  existing="$(_existing_job_command "$label" 2>/dev/null)"
  [ -n "$existing" ] || return 0
  # Strip quote characters before comparing: the F09 fix embeds literal "…" around $PERMA in the
  # generated command (so a space in the path survives launchd re-parsing it), and on darwin the
  # F15 fix XML-escapes the plist's stored text — neither ever appears in a real filesystem path,
  # so stripping them can't hide a genuine mismatch, but leaving them in broke this exact
  # comparison: "$home"/runtime/... contains the substring $home"/, not $home/, so an install's
  # own job was being reported as belonging to someone else.
  existing_bare="${existing//\"/}"
  case "$existing_bare" in *"$home/"*) return 0 ;; esac
  echo "  WARN — '$label' belongs to a DIFFERENT Permanence, so it has been left untouched:"
  echo "      already scheduled: $existing"
  echo "      this Permanence:   $home"
  if [ "$intent" = "remove" ]; then
    echo "      Refusing to remove another install's scheduled task. If you did mean to remove that"
    echo "      one, run this from the Permanence that owns it, or delete the task by hand."
  else
    echo "      would have run:    $intent"
    echo "      One Permanence per machine owns a given scheduled task. If THIS one should take it"
    echo "      over, remove the existing job first, then re-run install.sh."
  fi
  return 1
}

schedule_task() {
  local label="$1" command="$2" spec="$3"
  local perma_home; perma_home="$(_perma_home)"
  _perma_owns_job "$label" "$command" || return 0
  case "$(_perma_os)" in
    darwin)
      local plist_label; plist_label="com.$(id -un).${label}"
      local plist_dst="$HOME/Library/LaunchAgents/${plist_label}.plist"
      mkdir -p "$HOME/Library/LaunchAgents"
      # $command carries redirects (>>, 2>&1) and, since the F09 fix, quote characters — none of
      # those need XML escaping, but `&` (already present via 2>&1) and a bare `<`/`>` do: unescaped,
      # `plutil -lint` rejects the plist ("unknown ampersand-escape sequence"), confirmed against the
      # live install. launchd currently tolerates it, but the file itself is malformed XML.
      local escaped_command
      escaped_command="$(printf '%s' "$command" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')"
      {
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
        echo '<plist version="1.0"><dict>'
        echo "  <key>Label</key><string>$plist_label</string>"
        echo "  <key>ProgramArguments</key><array><string>/bin/bash</string><string>-c</string><string>$escaped_command</string></array>"
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
        && echo "  launchd: $label scheduled ($plist_label) — runs from $perma_home" \
        || echo "  launchd: WARN — $label bootstrap failed, load manually: launchctl bootstrap gui/$(id -u) $plist_dst"
      ;;
    linux)
      local cron_line marker="# $label"
      cron_line="$(_cron_spec "$spec") $command $marker"
      ( crontab -l 2>/dev/null | grep -vF "$marker"; echo "$cron_line" ) | crontab -
      if [ $? -eq 0 ]; then echo "  cron: $label scheduled — runs from $perma_home"; else echo "  cron: WARN — could not install crontab entry for $label, add by hand: $cron_line"; fi
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
      if [ $? -eq 0 ]; then echo "  schtasks: $label scheduled — runs from $perma_home"; else echo "  schtasks: WARN — could not create task $label, run by hand: MSYS_NO_PATHCONV=1 schtasks /Create /SC $sc ${d:+/D $d} /ST $st /TN $label /TR '$tr_cmd' /F"; fi
      ;;
    *)
      echo "  WARN — unrecognized OS ($(uname -s)); skipping scheduling for $label. Run it manually or via your own scheduler: $command"
      ;;
  esac
}

unschedule_task() {
  local label="$1"
  # Removing another Permanence's job is as damaging as overwriting it — same guard, same refusal.
  _perma_owns_job "$label" "remove" || return 0
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
