#!/bin/bash
# Make an age-encrypted backup of the whole Permanence (all history, one opaque file).
# Repeatable: run any time to refresh the backup. Restore = decrypt + git clone (see below).
#
# ONE-TIME SETUP (do once, before the first run):
#   age-keygen -o ~/.config/age/perma-backup.key
#   → copy that key file's contents into your password manager + one more place.
#     Lose the laptop: restore from the blob + key. Lose the key: the backup is gone.
#     NEVER store the key alongside the .age blob.
#
# RESTORE (pick the dated bundle you want — newest unless you're deliberately rolling back):
#   age -d -i ~/.config/age/perma-backup.key -o permanence.bundle ~/Backups/perma-YYYY-MM-DD-HHMM.bundle.age
#   git clone permanence.bundle ~/permanence
#   git -C ~/permanence remote remove origin
#   git -C ~/permanence config core.hooksPath .githooks   # re-arm the people-guard
#   bash ~/permanence/runtime/install.sh                  # rebuilds commands, skills, harness hooks, CLAUDE.md
#
# TWO artefacts are written, because two different problems:
#   perma-*.bundle.age       Permanence itself — full git history. Also carries everything install.sh
#                            can REBUILD: commands, personal skills, harness hooks, the CLAUDE.md blocks.
#   claude-state-*.tar.age   the bits install.sh CANNOT rebuild — Claude's memory files, settings.json,
#                            and the skills' credentials files (deliberately kept out of Permanence repo).
#
#   RESTORE the state blob, after Permanence is back and install.sh has run:
#     age -d -i ~/.config/age/perma-backup.key ~/Backups/claude-state-YYYY-MM-DD-HHMM.tar.age \
#       | tar -xzf - -C ~
set -euo pipefail
PERMA="${PERMA_DIR:-$HOME/permanence}"
KEY="$HOME/.config/age/perma-backup.key"
KEEP=3                                          # dated bundles to retain locally (real retention = your off-machine Drive copies)
OUT="$HOME/Backups/perma-$(date +%Y-%m-%d-%H%M).bundle.age"
[ -f "$KEY" ] || { echo "No key at $KEY — run: age-keygen -o $KEY (then store it safely)"; exit 1; }
RECIP=$(grep -oE 'age1[a-z0-9]+' "$KEY" | head -1)
[ -n "$RECIP" ] || { echo "Could not read public recipient from $KEY"; exit 1; }
mkdir -p "$(dirname "$OUT")"
TMP=$(mktemp /tmp/permanence.bundle.XXXXXX)
VER=$(mktemp /tmp/permanence.verify.XXXXXX)
trap 'rm -f "$TMP" "$VER"' EXIT
git -C "$PERMA" bundle create "$TMP" --all
git -C "$PERMA" bundle verify "$TMP" >/dev/null
age -r "$RECIP" -o "$OUT.tmp" "$TMP"
mv "$OUT.tmp" "$OUT"                         # atomic swap — never clobber a good copy
# round-trip: decrypt the blob we just wrote + verify it restores, before trusting it
age -d -i "$KEY" -o "$VER" "$OUT"
git -C "$PERMA" bundle verify "$VER" >/dev/null
echo "OK  wrote $OUT ($(du -h "$OUT" | cut -f1)) · recipient $RECIP · round-trip verified"

# --- second artefact: the ~/.claude state install.sh cannot rebuild ---------------------------
# Allowlist, never a blanket tar of ~/.claude: that directory also holds sessions/, history.jsonl,
# shell-snapshots/ and telemetry — full transcript history we do not want in a backup blob.
SOUT="$HOME/Backups/claude-state-$(date +%Y-%m-%d-%H%M).tar.age"
LIST=$(mktemp /tmp/claude.state.XXXXXX)
STAR=$(mktemp /tmp/claude.state.tar.XXXXXX)
trap 'rm -f "$TMP" "$VER" "$LIST" "$STAR"' EXIT
{
  find "$HOME/.claude/projects" -maxdepth 2 -type d -name memory 2>/dev/null
  find "$HOME/.claude/skills" -name credentials 2>/dev/null      # secrets: kept OUT of Permanence repo
  for f in "$HOME/.claude/settings.json" "$HOME/.claude/settings.local.json"; do
    [ -f "$f" ] && echo "$f"
  done
} | sed "s|^$HOME/||" > "$LIST"

if [ -s "$LIST" ]; then
  tar -czf "$STAR" -C "$HOME" -T "$LIST"
  age -r "$RECIP" -o "$SOUT.tmp" "$STAR"
  mv "$SOUT.tmp" "$SOUT"
  # round-trip: decrypt and confirm the archive lists, before trusting it
  age -d -i "$KEY" "$SOUT" | tar -tzf - >/dev/null
  echo "OK  wrote $SOUT ($(du -h "$SOUT" | cut -f1)) · $(wc -l < "$LIST" | tr -d ' ') paths · round-trip verified"
  ls -1t "$HOME/Backups"/claude-state-*.tar.age 2>/dev/null | tail -n +$((KEEP+1)) | while IFS= read -r old; do
    rm -f "$old" && echo "    pruned older local state backup: $(basename "$old")"
  done
else
  echo "WARN  no ~/.claude state paths matched — state blob NOT written"
fi
# Retain only the last $KEEP dated bundles locally; prune older ones (newest-first by mtime).
ls -1t "$HOME/Backups"/perma-*.bundle.age 2>/dev/null | tail -n +$((KEEP+1)) | while IFS= read -r old; do
  rm -f "$old" && echo "    pruned older local backup: $(basename "$old")"
done
echo "    local retention: newest $KEEP kept in ~/Backups. Upload THIS file to your Drive and keep 3 there (real off-machine retention)."
