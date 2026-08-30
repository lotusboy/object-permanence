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
while IFS= read -r line; do
  # A row missing its leading "|" used to silently shift every field by one — the workspace path
  # column would be read as the stream name, fail the "starts with /" check below, and the row
  # would vanish with no signal that it was ever in the file. Requiring the (whitespace-trimmed)
  # line to start with "|" makes that skip an explicit, intentional one instead of an accident of
  # how IFS='|' happens to split a malformed row.
  trimmed="${line#"${line%%[![:space:]]*}"}"
  case "$trimmed" in ('|'*) ;; (*) continue ;; esac
  IFS='|' read -r _ ws stream _ <<< "$line"
  ws=$(echo "$ws" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  stream=$(echo "$stream" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  case "$ws" in (/*) ;; (*) continue;; esac          # only path rows
  # Normalize a trailing slash before comparing — "/Users/me/proj/" and "/Users/me/proj" must
  # match the same workspaces. Left as-is, a trailing slash made a row match NEITHER the
  # directory itself nor anything under it, so it silently matched nothing at all.
  case "$ws" in (?*/) ws="${ws%/}" ;; esac
  case "$TARGET" in
    ("$ws"|"$ws"/*)
      if [ ${#ws} -gt ${#BEST_PATH} ]; then BEST_PATH="$ws"; BEST_STREAM="$stream"; fi
      ;;
  esac
done < "$REG"

[ -n "$BEST_STREAM" ] && printf '%s\n' "$BEST_STREAM"
exit 0
