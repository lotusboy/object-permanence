#!/bin/bash
# Bind Permanence's runtime to this machine's Claude Code harness (hardening item 5 / F2).
# Idempotent — run after clone, after pulling runtime changes, or any time to verify.
# Copy-on-install (NOT symlinks): installed copies carry a version marker; symlinked
# commands would track whatever ref the working tree has checked out.

set -u
PERMA="${PERMA_DIR:-$HOME/permanence}"
CMD_SRC="$PERMA/runtime/commands"
CMD_DST="$HOME/.claude/commands"
SHA=$(git -C "$PERMA" rev-parse --short HEAD 2>/dev/null || echo "unversioned")

echo "Permanence install — runtime @ $SHA"

# 1. Commands: copy with version marker appended
mkdir -p "$CMD_DST"
for f in "$CMD_SRC"/*.md; do
  name=$(basename "$f")
  cp "$f" "$CMD_DST/$name"
  printf '\n<!-- installed-from: ~/permanence/runtime/commands/%s @ %s — edit the source in Permanence, then re-run ~/permanence/runtime/install.sh -->\n' "$name" "$SHA" >> "$CMD_DST/$name"
  echo "  command: $name"
done

# 2. Executable bits + git hooks path (re-run needed once after any re-clone)
chmod +x "$PERMA/runtime/"*.sh "$PERMA/.githooks/"* 2>/dev/null
git -C "$PERMA" config core.hooksPath .githooks
echo "  hooks: core.hooksPath=.githooks (pre-commit people-guard + post-commit contents refresh)"

# 3. Scheduled tasks — cross-platform via schedule-task.sh (launchd/cron/schtasks, per OS)
mkdir -p "$PERMA/runtime/logs"
source "$PERMA/runtime/schedule-task.sh"
schedule_task "perma-consolidate" "$PERMA/runtime/nightly-consolidate.sh >> $PERMA/runtime/logs/nightly-consolidate.log 2>&1" "daily 05:30"
schedule_task "perma-cogdebt" "$PERMA/runtime/cogdebt-scan.sh --quiet >> $PERMA/runtime/logs/cogdebt.log 2>&1" "weekday 1 06:00"
echo "  (weekly cognitive-debt scan: edit the REPOS watch-list in runtime/cogdebt-scan.sh first)"

# 4. CLAUDE.md: manage ONLY the delimited Permanence block (never touch the rest of the file)
CMD_MD="$HOME/.claude/CLAUDE.md"
BLOCK_SRC="$PERMA/runtime/claude-md-block.md"
if [ -f "$BLOCK_SRC" ]; then
  if grep -q '<!-- perma:begin' "$CMD_MD" 2>/dev/null; then
    # replace existing block in place
    awk -v src="$BLOCK_SRC" '
      /<!-- perma:begin/ {while ((getline line < src) > 0) print line; close(src); skip=1; next}
      /<!-- perma:end -->/ {skip=0; next}
      !skip {print}' "$CMD_MD" > "$CMD_MD.tmp" && mv "$CMD_MD.tmp" "$CMD_MD"
  else
    { cat "$BLOCK_SRC"; echo; cat "$CMD_MD" 2>/dev/null; } > "$CMD_MD.tmp" && mv "$CMD_MD.tmp" "$CMD_MD"
  fi
  echo "  CLAUDE.md: Permanence block refreshed"
fi

# 4b. AGENTS.md (Tier 2 — other AI tools): same delimited-block merge, into GLOBAL per-machine
#     paths ONLY — never a project-committed AGENTS.md, which invariant 1 forbids (that file is
#     meant to be shared with every contributor). Only touches a tool's config path if that tool's
#     own config directory already exists (real signal it's installed) — never invents one. The
#     emerging unifying standard path is written unconditionally since it's dedicated to exactly
#     this purpose, not a directory shared by unrelated tools.
AGENTS_BLOCK_SRC="$PERMA/runtime/agents-md-block.md"
merge_agents_block() {  # merge_agents_block <target-file>
  local dst="$1"
  [ -f "$AGENTS_BLOCK_SRC" ] || return 0
  mkdir -p "$(dirname "$dst")"
  if grep -q '<!-- perma:begin' "$dst" 2>/dev/null; then
    awk -v src="$AGENTS_BLOCK_SRC" '
      /<!-- perma:begin/ {while ((getline line < src) > 0) print line; close(src); skip=1; next}
      /<!-- perma:end -->/ {skip=0; next}
      !skip {print}' "$dst" > "$dst.tmp" && mv "$dst.tmp" "$dst"
  else
    { cat "$AGENTS_BLOCK_SRC"; echo; cat "$dst" 2>/dev/null; } > "$dst.tmp" && mv "$dst.tmp" "$dst"
  fi
  echo "  AGENTS.md: Permanence block refreshed at $dst"
}
merge_agents_block "$HOME/.config/agents/AGENTS.md"                 # emerging unifying standard — always
[ -d "$HOME/.codex" ]   && merge_agents_block "$HOME/.codex/AGENTS.md"    # OpenAI Codex, if installed
[ -d "$HOME/.factory" ] && merge_agents_block "$HOME/.factory/AGENTS.md" # droid, if installed
[ -f "$HOME/.config/AGENTS.md" ] && merge_agents_block "$HOME/.config/AGENTS.md"  # Amp, if it already exists
# Devin's and Google Antigravity's own global-config paths weren't confirmed at time of writing —
# verify and add here before relying on automatic Tier 2 coverage for those specifically; until
# then they fall back to the manual pointer (see docs/OTHER-TOOLS.md).

# 5. settings.json: safely MERGE the SessionStart hook + ~/permanence permission
#    (add only if absent; preserve everything else; back up before writing).
SETTINGS="$HOME/.claude/settings.json"
if command -v python3 >/dev/null 2>&1; then
  python3 - "$SETTINGS" "$PERMA" <<'PY'
import json, sys, os, shutil
path, perma = sys.argv[1], sys.argv[2]
os.makedirs(os.path.dirname(path), exist_ok=True)
data = {}
if os.path.exists(path):
    try:
        data = json.load(open(path))
    except Exception:
        print("  settings.json: present but unparseable — NOT touched. Add the hook + permission by hand."); sys.exit(0)
cmd = f"{perma}/runtime/session-start.sh"
changed = False
ad = data.setdefault("permissions", {}).setdefault("additionalDirectories", [])
if perma not in ad:
    ad.append(perma); changed = True
ss = data.setdefault("hooks", {}).setdefault("SessionStart", [])
present = any(isinstance(e, dict) and any(h.get("command") == cmd for h in e.get("hooks", [])) for e in ss)
if not present:
    ss.append({"hooks": [{"type": "command", "command": cmd, "timeout": 10}]}); changed = True
# UserPromptSubmit: session-load — RELIABLE per-session context auto-load (SessionStart context is
# passive; this fires on the user's first prompt so the model actually reads the stream). Core, so
# auto-wired (unlike events, which is opt-in).
cmd_load = f"{perma}/runtime/session-load.sh"
ups = data.setdefault("hooks", {}).setdefault("UserPromptSubmit", [])
if not any(isinstance(e, dict) and any(h.get("command") == cmd_load for h in e.get("hooks", [])) for e in ups):
    ups.insert(0, {"hooks": [{"type": "command", "command": cmd_load, "timeout": 10}]}); changed = True
if changed:
    if os.path.exists(path): shutil.copy(path, path + ".perma-bak")
    json.dump(data, open(path, "w"), indent=2)
    print("  settings.json: SessionStart + session-load (auto context) hooks + ~/permanence permission merged in (backup: settings.json.perma-bak)")
else:
    print("  settings.json: hook + permission already present")
PY
else
  cat <<SETTINGS
  settings.json: python3 not found — add these by hand to ~/.claude/settings.json (MERGE, don't overwrite):
      "permissions": { "additionalDirectories": ["$HOME/permanence"] },
      "hooks": {
        "SessionStart": [ { "hooks": [ { "type": "command", "command": "$HOME/permanence/runtime/session-start.sh", "timeout": 10 } ] } ],
        "UserPromptSubmit": [ { "hooks": [ { "type": "command", "command": "$HOME/permanence/runtime/session-load.sh", "timeout": 10 } ] } ]
      }
SETTINGS
fi

# 6. Events (cross-project notifications) — OPT-IN. The scripts (emit-event / events-listen /
#    stop-listen / resolve-stream) + the /perma-emit command are installed by steps 1-2. *Emitting*
#    works now; *receiving* uses two machine-wide hooks we DON'T auto-wire (your call):
#      • UserPromptSubmit → events-listen.sh  — delivers waiting messages on a session's next prompt
#      • Stop            → stop-listen.sh     — catches messages that land mid-turn, right as a session
#                                               would go idle (blocks the stop so it reads them). FREE:
#                                               a local file read; costs a turn only when there IS a message.
#    Both share one per-stream cursor, so each message is delivered exactly once across them.
echo "  events: scripts + /perma-emit installed. To ENABLE delivery (opt-in), add BOTH to ~/.claude/settings.json hooks:"
echo "      \"UserPromptSubmit\": [ { \"hooks\": [ { \"type\": \"command\", \"command\": \"$PERMA/runtime/events-listen.sh\", \"timeout\": 10 } ] } ],"
echo "      \"Stop\":             [ { \"hooks\": [ { \"type\": \"command\", \"command\": \"$PERMA/runtime/stop-listen.sh\",  \"timeout\": 10 } ] } ]"

# 7. Semantic search (/perma-search) — OPT-IN. The command + scripts are installed above; the
#    local embedding index needs a one-time venv (chromadb, local ONNX model, zero API, Python >=3.10).
echo "  /perma-search: to enable semantic search, set up its local venv (one-time, no API):"
echo "      uv venv $PERMA/runtime/search/.venv --python 3.12 && uv pip install --python $PERMA/runtime/search/.venv/bin/python -r $PERMA/runtime/search/requirements.txt"
echo "      then: $PERMA/runtime/search/.venv/bin/python $PERMA/runtime/search/perma-search.py build   (the post-commit hook keeps it fresh after that)"

# 8. Shutdown nudge (macOS) — OPT-IN. A weekday end-of-day notification reminding you to run
#    /perma-shutdown. Not installed automatically (a desktop ping is a personal choice).
echo "  shutdown nudge: to get a weekday reminder to run /perma-shutdown, enable it:"
echo "      $PERMA/runtime/shutdown-nudge.sh --install 17:00   (change the time, or --uninstall to remove)"

echo "done."
