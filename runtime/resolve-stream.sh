#!/bin/bash
# resolve-stream.sh <path> — print Permanence stream registered for <path> (longest-prefix
# match against _meta/REGISTRY.md), or print nothing if unregistered. Factored out of
# session-start.sh so the events listener can resolve a session's stream the same way.
# Output: the stream name on stdout (e.g. "home/kitchen" or "perma-meta"), or empty.

PERMA="${PERMA_DIR:-$HOME/permanence}"
REG="$PERMA/_meta/REGISTRY.md"
[ -f "$REG" ] || exit 0

TARGET="${1:-$(pwd -P)}"

BEST_PATH=""
BEST_STREAM=""
while IFS='|' read -r _ ws stream _; do
  ws=$(echo "$ws" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  stream=$(echo "$stream" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  case "$ws" in (/*) ;; (*) continue;; esac          # only path rows
  case "$TARGET" in
    ("$ws"|"$ws"/*)
      if [ ${#ws} -gt ${#BEST_PATH} ]; then BEST_PATH="$ws"; BEST_STREAM="$stream"; fi
      ;;
  esac
done < "$REG"

[ -n "$BEST_STREAM" ] && printf '%s\n' "$BEST_STREAM"
exit 0
