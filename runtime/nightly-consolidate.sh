#!/bin/bash
# Nightly read-only /perma-consolidate (hardening item 3), run by launchd
# (the launchd plist install.sh generates — installed by install.sh).
# Generation is pure analysis: it writes only a report under ~/permanence/.consolidation/ (gitignored).
# The scoped --allowedTools list below is the "scoped permission profile" — the run is
# unattended, so it gets read access + report-write + git log, and nothing else.

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
# Load Claude auth. launchd's bash sources no shell config, so the token must be loaded explicitly —
# this was the cause of the prior 401s. Checked in order; the first file that exists is sourced.
# Keeping the token in its own file (rather than the global shell env) stops it leaking into VS Code
# and shadowing Claude Code's own login.
#   1. $PERMA_TOKEN_ENV                                  — explicit override, set it to any path
#   2. ~/.config/perma/claude-code-oauth-token.env        — the documented default
#   3. ~/.zshenv                                          — legacy fallback (grepped, not sourced)
for _tok in "${PERMA_TOKEN_ENV:-}" \
            "$HOME/.config/perma/claude-code-oauth-token.env"; do
  # shellcheck disable=SC1090
  [ -n "$_tok" ] && [ -f "$_tok" ] && { . "$_tok"; break; }
done
[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && [ -f "$HOME/.zshenv" ] && \
  eval "$(grep -E '^[[:space:]]*export (CLAUDE_CODE_OAUTH_TOKEN|ANTHROPIC_AUTH_TOKEN|ANTHROPIC_BASE_URL)=' "$HOME/.zshenv")"
# Permanence runs on your Claude CODE SUBSCRIPTION, never an API key. This loads a subscription/OAuth
# token only — generate one with `claude setup-token` (→ CLAUDE_CODE_OAUTH_TOKEN). It deliberately does
# NOT load ANTHROPIC_API_KEY (keep any API key for other tools; Permanence never uses it).
PERMA="${PERMA_DIR:-$HOME/permanence}"
LOG_DIR="$PERMA/runtime/logs"; mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/nightly-consolidate.log"

note() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; }

# Best-effort failure alert via the events outbox — so a failure surfaces in the next session you open,
# instead of being buried in a log nobody reads. Emitted as source "nightly" (not a real stream) so every
# open session surfaces it and none is skipped by the no-echo rule. No-ops harmlessly if events aren't
# enabled. Guarded with || true: a failed alert must never mask the original error.
alert() {
  [ -x "$PERMA/runtime/emit-event.sh" ] && \
    PERMA_EMIT_SOURCE="nightly" "$PERMA/runtime/emit-event.sh" all "$1" >/dev/null 2>&1 || true
}

CLAUDE_BIN="$(command -v claude)"
if [ -z "$CLAUDE_BIN" ]; then note "ERROR: claude CLI not found on PATH"; alert "Nightly consolidate FAILED: claude CLI not on PATH. See runtime/logs/nightly-consolidate.log."; exit 1; fi
if [ ! -d "$PERMA/.git" ]; then note "ERROR: ~/permanence is not a git repo"; exit 1; fi

# Pre-flight auth assert — a missing subscription token is a HARD STOP, never a reason to use an API key.
# Makes the failure loud + unambiguous instead of letting claude attempt an unauthenticated run.
if [ -z "$CLAUDE_CODE_OAUTH_TOKEN" ] && [ -z "$ANTHROPIC_AUTH_TOKEN" ]; then
  note "ERROR: no Claude subscription token loaded (CLAUDE_CODE_OAUTH_TOKEN empty) — ABORTING. Will NOT fall back to an API key. FIX: run 'claude setup-token', then save the token as a single line — export CLAUDE_CODE_OAUTH_TOKEN=<token> — in ~/.config/perma/claude-code-oauth-token.env (or set PERMA_TOKEN_ENV to wherever you keep it)."
  alert "Nightly consolidate ABORTED $(date '+%Y-%m-%d'): no Claude subscription token loaded — it will NOT use an API key. FIX: run 'claude setup-token', then put 'export CLAUDE_CODE_OAUTH_TOKEN=<token>' in ~/.config/perma/claude-code-oauth-token.env (chmod 600)."
  exit 78
fi

# Respect the consolidation lock: a live review owns Permanence right now.
if [ -f "$PERMA/.perma-lock" ]; then note "SKIPPED: .perma-lock present"; exit 0; fi

note "run start"
cd "$PERMA" || exit 1

# Marker for the artefact assert below: any REPORT written by THIS run is newer than this file.
MARKER="$(mktemp "${TMPDIR:-/tmp}/perma-consolidate.marker.XXXXXX")"
mkdir -p "$PERMA/.consolidation"

# --allowedTools entries are matched as LITERAL PREFIXES, so a granted "$HOME/permanence" path can never
# match a command the model writes as "~/permanence" (and the bare "git log:*" fallback misses too, because
# the command begins "git -C"). Headless there is nobody to approve the prompt, so the call is simply
# denied and the model gives up. Grant BOTH spellings of every path.
"$CLAUDE_BIN" -p "/perma-consolidate" \
  --permission-mode default --model sonnet \
  --allowedTools "Read" "Glob" "Grep" "Write" \
    "Bash(git -C $HOME/permanence log:*)" "Bash(git -C ~/permanence log:*)" "Bash(git log:*)" \
    "Bash(date:*)" "Bash(ls:*)" \
    "Bash(mkdir -p $HOME/permanence/.consolidation:*)" "Bash(mkdir -p ~/permanence/.consolidation:*)" \
  >> "$LOG" 2>&1
RC=$?

# Assert the ARTEFACT, not just the exit code. A denied tool makes the model give up while `claude`
# still exits 0 — which used to be logged as "run complete" with no report written. The morning brief
# then saw an empty .consolidation/ and read it as "nothing to do", when it meant "nothing ran".
# Silent-green is worse than a loud failure, so an absent report is now an error in its own right.
NEW_REPORT="$(find "$PERMA/.consolidation" -maxdepth 1 -name 'REPORT-*.md' -newer "$MARKER" -print -quit 2>/dev/null)"
rm -f "$MARKER"

if [ $RC -ne 0 ]; then
  note "ERROR: run failed (exit $RC)"
  alert "Nightly consolidate FAILED (exit $RC) on $(date '+%Y-%m-%d'). NOT an API-key fallback — most likely the subscription token expired; re-run 'claude setup-token'. Log: runtime/logs/nightly-consolidate.log."
  exit $RC
elif [ -z "$NEW_REPORT" ]; then
  note "ERROR: run exited 0 but wrote NO report to .consolidation/ — treating as a failure. Most likely a tool call was denied (check the log for permission errors); the model cannot work and gives up while still exiting 0."
  alert "Nightly consolidate produced NO REPORT on $(date '+%Y-%m-%d') despite exiting 0 — almost certainly a denied tool call, so nothing actually ran. An empty .consolidation/ means NOT-RUN, not caught-up. Log: runtime/logs/nightly-consolidate.log."
  exit 70
else
  note "run complete (exit 0) — wrote $(basename "$NEW_REPORT")"
  exit 0
fi
