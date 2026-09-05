#!/bin/bash
# resolve-path.sh <stream-name> — print the registered workspace path(s) for a Permanence
# stream (exact match on _meta/REGISTRY.md's stream column), one per line. Prints nothing if
# the stream has no registered path. Reverse of resolve-stream.sh, for commands that resolve
# a session by stream name instead of by cwd (desktop AI apps, no meaningful working folder).

PERMA="${PERMA_DIR:-$HOME/permanence}"
REG="$PERMA/_meta/REGISTRY.md"
[ -f "$REG" ] || exit 0

TARGET="${1:-}"
[ -n "$TARGET" ] || exit 0

while IFS= read -r line; do
  # Same leading-"|" guard as resolve-stream.sh: a malformed row (missing its leading "|")
  # would otherwise shift every field by one and match nothing, silently.
  trimmed="${line#"${line%%[![:space:]]*}"}"
  case "$trimmed" in ('|'*) ;; (*) continue ;; esac
  IFS='|' read -r _ ws stream _ <<< "$line"
  ws=$(echo "$ws" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  stream=$(echo "$stream" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  case "$ws" in (/*) ;; (*) continue;; esac          # only path rows
  [ "$stream" = "$TARGET" ] && printf '%s\n' "$ws"
done < "$REG"

exit 0
