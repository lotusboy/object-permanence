#!/bin/bash
# Regenerate Permanence's CONTENTS.md inventories.
#   generate-contents.sh            -> regenerate all stream inventories + the full-Permanence one
#   generate-contents.sh <stream>   -> regenerate one stream (path relative to ~/permanence) + the full one
# CONTENTS.md files are derived output: gitignored, rebuilt freely (also via .githooks/post-commit).
#
# PLAIN, NO LINKS — on purpose. VS Code's markdown preview sanitizes file:// links (renders them
# non-clickable), the chat panel mangles them, and relative links mis-resolve across workspaces.
# Clickable links never worked reliably. Navigation lives in the VS Code Explorer instead
# (add ~/permanence as a folder). These files are a *readable dated inventory*: what's in a stream and
# when each thing was last touched (newest first). You read them; you click files in the Explorer.

PERMA="${PERMA_DIR:-$HOME/permanence}"
cd "$PERMA" || exit 1
TS="$(date '+%Y-%m-%d %H:%M')"

stream_index() {  # $1 = stream dir (relative to Permanence root) — list newest-first by mtime
  local dir="$1"
  {
    printf '# Contents — %s\n\n' "$dir"
    printf '> Generated %s by runtime/generate-contents.sh — derived, gitignored, do not edit.\n' "$TS"
    printf '> Dated inventory (newest first). **Navigate by clicking files in the VS Code Explorer** (add `~/permanence` as a folder); this file is the at-a-glance "what is here + when".\n\n'
    find "$dir" \( -name .git -o -name .consolidation -o -name node_modules \) -prune -o \
      -type f ! -name 'CONTENTS.md' ! -name '.DS_Store' ! -name '.perma-lock' -print 2>/dev/null \
      | while IFS= read -r f; do
          rel="${f#"$dir"/}"; [ "$rel" = "$f" ] && rel="$f"
          printf '%s\t%s\t%s\n' "$(stat -f '%m' "$f" 2>/dev/null)" "$(stat -f '%Sm' -t '%Y-%m-%d' "$f" 2>/dev/null)" "$rel"
        done | sort -rn | while IFS=$'\t' read -r _ d rel; do
          printf -- '- %s — %s\n' "$rel" "$d"
        done
  } > "$dir/CONTENTS.md"
}

full_index() {  # whole Permanence, grouped by folder, alphabetical
  {
    printf '# Contents — full Permanence\n\n'
    printf '> Generated %s by runtime/generate-contents.sh — derived, gitignored, do not edit.\n' "$TS"
    printf '> Dated inventory. **Navigate via the VS Code Explorer** (add `~/permanence` as a folder).\n\n'
    printf '## Root\n'
    find . -maxdepth 1 -type f ! -name 'CONTENTS.md' ! -name '.DS_Store' ! -name '.perma-lock' -print | sed 's|^\./||' | sort \
      | while IFS= read -r f; do printf -- '- %s — %s\n' "$f" "$(stat -f '%Sm' -t '%Y-%m-%d' "$f" 2>/dev/null)"; done
    for d in $(find . \( -name .git -o -name .consolidation \) -prune -o -maxdepth 2 -mindepth 1 -type d -print | sed 's|^\./||' | sort); do
      case "$d" in (.git*|.consolidation*|runtime/*) continue;; esac
      [ -z "$(find "$d" -maxdepth 1 -type f ! -name 'CONTENTS.md' ! -name '.DS_Store' | head -1)" ] && continue
      printf '\n## %s\n' "$d"
      find "$d" -maxdepth 1 -type f ! -name 'CONTENTS.md' ! -name '.DS_Store' -print | sort \
        | while IFS= read -r f; do printf -- '- %s — %s\n' "$f" "$(stat -f '%Sm' -t '%Y-%m-%d' "$f" 2>/dev/null)"; done
    done
  } > "CONTENTS.md"
}

if [ -n "$1" ] && [ "$1" != "--quiet" ]; then
  [ -d "$1" ] && stream_index "$1"
else
  find . -name .git -prune -o -name PROJECT.md -print 2>/dev/null | sed 's|^\./||;s|/PROJECT.md$||' | while IFS= read -r s; do
    stream_index "$s"
  done
fi
full_index
[ "$1" = "--quiet" ] || [ "$2" = "--quiet" ] || echo "CONTENTS.md regenerated (plain inventory; streams + full)."
exit 0
