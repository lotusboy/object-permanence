#!/usr/bin/env bash
# emit-event.sh <target> [message...] — emit a Permanence event from THIS session's stream.
#   target  = "all" (every other open session) or a specific stream name (e.g. "home/kitchen").
#   source  = auto-resolved from cwd via the registry; pass PERMA_EMIT_SOURCE to override.
#
# The event lands in the shared outbox ~/permanence/_meta/events.jsonl (append-only). Other open
# sessions' listeners surface it into their CONTEXT — never into project files (one-way flow:
# events flow into attention, not committed artefacts). The emitting stream never sees its own
# event echoed back (the listener skips source==self).
set -euo pipefail

PERMA="${PERMA_DIR:-$HOME/permanence}"
OUTBOX="$PERMA/_meta/events.jsonl"

tgt="${1:?usage: emit-event.sh <target|all> [message...]}"; shift || true
msg="$*"
[ -n "$msg" ] || { echo "emit-event: empty message" >&2; exit 1; }

src="${PERMA_EMIT_SOURCE:-$("$PERMA/runtime/resolve-stream.sh" "$(pwd -P)")}"
[ -n "$src" ] || { echo "emit-event: this workspace is not a registered stream — cannot emit" >&2; exit 1; }

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
id="$(date +%s)-$$"

# JSON-escape every field via python (handles quotes/newlines safely)
python3 - "$id" "$ts" "$src" "$tgt" "$msg" >> "$OUTBOX" <<'PY'
import json, sys
id_, ts, src, tgt, msg = sys.argv[1:6]
print(json.dumps({"id": id_, "ts": ts, "source": src, "target": tgt, "message": msg}, ensure_ascii=False))
PY

echo "emitted [$src → $tgt]: $msg"
