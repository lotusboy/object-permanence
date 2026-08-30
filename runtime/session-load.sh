#!/usr/bin/env bash
# Permanence session-load (UserPromptSubmit hook) — reliable per-session context auto-load.
# ---------------------------------------------------------------------------------
# Why: the SessionStart hook injects "read this project's stream" as PASSIVE context, which the
# model sees but doesn't reliably ACT on until the user references it ("refer to Permanence"). A
# UserPromptSubmit hook fires on the user's actual turn, so the model acts on the injected
# instruction. This fires that load ONCE per session (first prompt only) when the workspace is a
# registered stream — then stays silent. Best-effort, local, zero output when there's nothing to do.
PERMA="${PERMA_DIR:-$HOME/permanence}"
[ -d "$PERMA" ] || exit 0

input=$(cat 2>/dev/null)   # UserPromptSubmit delivers a JSON object on stdin (session_id, cwd, …)
if command -v python3 >/dev/null 2>&1; then
  read -r SID CWD < <(printf '%s' "$input" | python3 -c '
import json,sys,os
try: d=json.load(sys.stdin)
except Exception: d={}
print(d.get("session_id") or d.get("transcript_path") or "nosid", d.get("cwd") or os.environ.get("PWD",""))
' 2>/dev/null)
else
  # No python3: without it, SID silently came back empty, the "${SID:-nosid}" check below then
  # read as already-nosid, the once-per-session marker never got set, and this hook's whole
  # auto-load paragraph re-injected on EVERY prompt of the session rather than just the first.
  # A plain-text extraction is good enough here — session_id/cwd are simple strings, and this is
  # a degraded fallback, not the primary path.
  SID="$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  CWD="$(printf '%s' "$input" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  [ -n "$SID" ] || SID="nosid"
fi
[ -n "${CWD:-}" ] || CWD="$PWD"

# Once per session: a marker keyed by session id. (Falls through to inject-every-prompt only in the
# rare case no session id is provided — functional, just chattier.)
if [ "${SID:-nosid}" != "nosid" ]; then
  marker="/tmp/.perma-loaded-$(printf '%s' "$SID" | tr -c 'A-Za-z0-9' _)"
  [ -f "$marker" ] && exit 0
fi

stream="$("$PERMA/runtime/resolve-stream.sh" "$CWD" 2>/dev/null)"
[ -z "$stream" ] && exit 0            # unregistered / non-Permanence workspace → nothing to load
[ "$stream" = "perma-meta" ] && { [ -n "${marker:-}" ] && touch "$marker"; exit 0; }  # brief-level only

[ -n "${marker:-}" ] && touch "$marker"
printf 'Permanence auto-load (once this session): this workspace is the "%s" stream. Before answering, read its current context now — %s/%s/PROJECT.md and QUESTIONS.md, plus the recent tail of LOG.md (and STRATEGY.md / PEOPLE.md if present) — so you continue with the project state instead of a blank slate. Keep it updated as things move.\n' "$stream" "$PERMA" "$stream"
