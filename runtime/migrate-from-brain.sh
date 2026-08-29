#!/usr/bin/env bash
# migrate-from-brain.sh — one-time migration for an existing pre-rebrand ~/brain install.
# Run this ONCE per install that predates the Permanence rebrand. A fresh clone of this repo
# never needs it — it exists purely for people upgrading from the old `brain`/`brain-template`
# naming to `permanence`. Safe to delete your own copy afterwards; nothing else depends on it.
#
# What it does:
#   1. Renames ~/brain -> ~/permanence.
#   2. Copies in THIS repo's own machinery (runtime/, .githooks/, templates/, docs) over the
#      renamed folder — it still contains the OLD brain-branded scripts until this happens;
#      running its own (old) install.sh would do nothing for the rebrand.
#   3. Cleans up the old launchd jobs, the old ~/.claude/commands/brain-*.md files, the old
#      <!-- brain:begin/end --> CLAUDE.md block, and any settings.json hook entries still
#      pointing at the old ~/brain path.
#   4. Runs the NEW install.sh from within ~/permanence to finish wiring.
#
# Usage: run it from wherever you cloned this repo (or downloaded a release of it):
#   bash runtime/migrate-from-brain.sh [old-path]
#   default old-path: ~/brain
set -euo pipefail

OLD="${1:-$HOME/brain}"
NEW="$HOME/permanence"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # this repo's own root — wherever it's checked out

echo "=== Permanence migration: $OLD -> $NEW (machinery from $SRC) ==="

if [ ! -d "$OLD" ]; then
  echo "No $OLD found — nothing to migrate."; exit 0
fi
if [ -d "$NEW" ]; then
  echo "ERROR: $NEW already exists — refusing to overwrite. Move it aside first if this is intentional."
  exit 1
fi
if [ ! -f "$SRC/runtime/install.sh" ]; then
  echo "ERROR: couldn't find this repo's own install.sh at $SRC/runtime/install.sh — something's wrong with how this script was invoked."
  exit 1
fi
if [ ! -d "$OLD/.git" ] && [ ! -f "$OLD/SPEC.md" ]; then
  echo "WARNING: $OLD doesn't look like a brain install (no .git, no SPEC.md)."
  read -r -p "Continue anyway? [y/N] " ans
  [ "$ans" = "y" ] || exit 1
fi

# 1. Unload old launchd jobs BEFORE anything moves (their plists reference the old path/labels)
for label in "com.$(id -un).brain-consolidate" "com.$(id -un).brain-cogdebt" "com.$(id -un).brain-shutdown-nudge"; do
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
  rm -f "$HOME/Library/LaunchAgents/$label.plist"
done
echo "  old launchd jobs unloaded"

# 2. Rename the folder
mv "$OLD" "$NEW"
echo "  moved $OLD -> $NEW"

# 3. Rename the lock file if present (unlikely mid-consolidation, but be safe)
[ -f "$NEW/.brain-lock" ] && mv "$NEW/.brain-lock" "$NEW/.perma-lock" && echo "  .brain-lock -> .perma-lock"

# 4. Migrate the token config dir if present
if [ -d "$HOME/.config/brain" ] && [ ! -d "$HOME/.config/perma" ]; then
  mv "$HOME/.config/brain" "$HOME/.config/perma"
  echo "  moved ~/.config/brain -> ~/.config/perma"
fi

# 5. Copy in the freshly rebranded machinery, same paths update.sh refreshes — the renamed
#    folder's own git history is untouched (this is a plain file copy, not a checkout), so the
#    owner still has every old commit; nothing here is destructive to history, only to the
#    working-tree copies of these specific paths.
for p in runtime .githooks templates SPEC.md README.md QUICKSTART.md CHANGELOG.md; do
  rm -rf "${NEW:?}/${p:?}"
  cp -R "$SRC/$p" "$NEW/$p"
done
mkdir -p "$NEW/_meta"
cp "$SRC/_meta/VERSION" "$NEW/_meta/VERSION" 2>/dev/null || true
chmod +x "$NEW/runtime/"*.sh "$NEW/.githooks/"* 2>/dev/null || true
echo "  machinery refreshed from $SRC"

# 6. Remove old installed commands (the new install.sh below installs the perma-* ones fresh)
rm -f "$HOME/.claude/commands"/brain-*.md
echo "  removed old ~/.claude/commands/brain-*.md"

# 7. Strip the OLD delimited CLAUDE.md block — the new install.sh looks for perma:begin/end
#    markers and won't find/replace this one, so left alone it would just sit there stale.
CMD_MD="$HOME/.claude/CLAUDE.md"
if [ -f "$CMD_MD" ] && grep -q '<!-- brain:begin' "$CMD_MD"; then
  awk '/<!-- brain:begin/{skip=1;next} /<!-- brain:end -->/{skip=0;next} !skip' "$CMD_MD" > "$CMD_MD.tmp" \
    && mv "$CMD_MD.tmp" "$CMD_MD"
  echo "  stripped the old brain:begin/end CLAUDE.md block"
fi

# 8. Strip OLD settings.json entries pointing at the now-gone $OLD path (new install.sh adds the
#    new $NEW-pointing ones — without this step you'd end up with both, one dead)
SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ] && command -v python3 >/dev/null 2>&1; then
  python3 - "$SETTINGS" "$OLD" <<'PY'
import json, sys, shutil
path, old = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(path))
except Exception:
    print("  settings.json: unparseable, skipping stale-hook cleanup — check by hand")
    sys.exit(0)
changed = False
ad = data.get("permissions", {}).get("additionalDirectories", [])
if old in ad:
    ad.remove(old); changed = True
for hook_type, entries in list(data.get("hooks", {}).items()):
    kept = []
    for e in entries:
        hooks = [h for h in e.get("hooks", []) if not h.get("command", "").startswith(old + "/")]
        if hooks:
            e["hooks"] = hooks
            kept.append(e)
        else:
            changed = True
    data["hooks"][hook_type] = kept
if changed:
    shutil.copy(path, path + ".pre-migration-bak")
    json.dump(data, open(path, "w"), indent=2)
    print("  settings.json: removed stale ~/brain-pointing entries (backup: settings.json.pre-migration-bak)")
else:
    print("  settings.json: no stale ~/brain entries found")
PY
fi

# 9. Run the now-rebranded install.sh to wire everything fresh
echo "  running install.sh to finish wiring ..."
bash "$NEW/runtime/install.sh"

echo ""
echo "✅ Migration complete: $NEW is now a normal, up-to-date Permanence install."
echo "   Start a fresh Claude Code session so the new hooks load."
echo "   Sanity-check: git -C \"$NEW\" log --oneline -5   (your full history should still be there)"
