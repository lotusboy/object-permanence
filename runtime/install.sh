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

# Tracks whether a step that matters actually succeeded, so the final line can say so honestly.
# Without this, install.sh printed "done." unconditionally — a failed cp, an unparseable
# settings.json, or a missing python3 all left the install silently incomplete while reporting
# success. Not every possible failure in this script is caught (a full `set -e` audit was judged
# riskier — several lines here rely on an expected, harmless failure via `2>/dev/null` or `||`,
# and blanket -e risks a NEW silent-abort mode instead of fixing this one); this covers the two
# concrete cases most likely to leave hooks unwired: the command copy and the settings.json write.
INSTALL_FAILED=0

echo "Permanence install — runtime @ $SHA"

# 1. Commands: copy with version marker appended
mkdir -p "$CMD_DST"
for f in "$CMD_SRC"/*.md; do
  name=$(basename "$f")
  if cp "$f" "$CMD_DST/$name"; then
    printf '\n<!-- installed-from: ~/permanence/runtime/commands/%s @ %s — edit the source in Permanence, then re-run ~/permanence/runtime/install.sh -->\n' "$name" "$SHA" >> "$CMD_DST/$name"
    echo "  command: $name"
  else
    echo "  command: $name — FAILED to copy"
    INSTALL_FAILED=1
  fi
done

# 2. Executable bits + git hooks path (re-run needed once after any re-clone)
chmod +x "$PERMA/runtime/"*.sh "$PERMA/.githooks/"* 2>/dev/null
git -C "$PERMA" config core.hooksPath .githooks
echo "  hooks: core.hooksPath=.githooks (pre-commit people-guard + post-commit contents refresh)"

# 3. Scheduled tasks — cross-platform via schedule-task.sh (launchd/cron/schtasks, per OS)
mkdir -p "$PERMA/runtime/logs"
source "$PERMA/runtime/schedule-task.sh"
# $PERMA is embedded here inside its own literal double-quotes ("$PERMA"), not bare — this
# string is re-parsed as a shell command line a second time, by launchd/cron/schtasks, once the
# scheduled job actually fires. A bare, unquoted $PERMA containing a space (a real macOS
# possibility — "/Users/Anna Smith") word-splits at that second parse: launchd tried to run
# "/Users/Anna" as the command with "Smith/permanence/..." as its argument, confirmed by running
# it. Embedding the quote characters now is what survives that second parse.
schedule_task "perma-consolidate" "\"$PERMA\"/runtime/nightly-consolidate.sh >> \"$PERMA\"/runtime/logs/nightly-consolidate.log 2>&1" "daily 05:30"

# Cognitive-debt scan: OPT-IN, matching README's own "Opt-in extras" listing — this is the fix,
# not just the comment. Auto-scheduling it unconditionally used to set up a weekly job that was
# guaranteed broken on every fresh install (the watch-list is a placeholder path until edited);
# cogdebt-scan.sh now refuses to run against that placeholder, so scheduling it before it's
# configured would just mean a weekly job that logs "not configured" instead of doing anything.
# Detected rather than a separate manual step: schedule it once the placeholder is actually gone.
if grep -q '/path/to/your/ai-built-repo' "$PERMA/runtime/cogdebt-scan.sh" 2>/dev/null; then
  echo "  cogdebt scan: NOT scheduled — edit the REPOS watch-list at the top of runtime/cogdebt-scan.sh, then re-run install.sh to schedule the weekly check"
else
  schedule_task "perma-cogdebt" "\"$PERMA\"/runtime/cogdebt-scan.sh --quiet >> \"$PERMA\"/runtime/logs/cogdebt.log 2>&1" "weekday 1 06:00"
fi

# 4. CLAUDE.md + AGENTS.md: manage ONLY the delimited Permanence block, never the rest of a
#    file we don't own. `_perma_block_merge` is the one place that splices into someone else's
#    file, so it carries the safety net: refuse to touch a mismatched begin/end pair (writing
#    through one would delete everything after it) and back up before any in-place replace.
_perma_block_merge() {  # _perma_block_merge <target-file> <block-source-file>
  local dst="$1" src="$2" begins ends begin_line end_line
  [ -f "$src" ] || return 0
  mkdir -p "$(dirname "$dst")"
  if [ -f "$dst" ] && grep -q '<!-- perma:begin' "$dst" 2>/dev/null; then
    begins=$(grep -c '<!-- perma:begin' "$dst")
    ends=$(grep -c '<!-- perma:end -->' "$dst")
    begin_line=$(grep -n '<!-- perma:begin' "$dst" | head -1 | cut -d: -f1)
    end_line=$(grep -n '<!-- perma:end -->' "$dst" | head -1 | cut -d: -f1)
    if [ "$begins" -ne "$ends" ] || [ -z "$end_line" ] || [ "$end_line" -le "$begin_line" ]; then
      echo "  WARN — $dst has a perma:begin marker with no matching perma:end after it (or a mismatched count). Left COMPLETELY UNTOUCHED — writing here would delete everything after the marker. Fix or remove the marker(s) by hand, then re-run install.sh."
      return 1
    fi
    cp "$dst" "$dst.perma-bak"
    awk -v s="$src" '
      /<!-- perma:begin/ {while ((getline line < s) > 0) print line; close(s); skip=1; next}
      /<!-- perma:end -->/ {skip=0; next}
      !skip {print}' "$dst" > "$dst.tmp" && mv "$dst.tmp" "$dst"
  else
    # No existing marker: this can only ever ADD content (prepend), never destroy any — no
    # backup needed, because nothing here can lose data.
    { cat "$src"; echo; cat "$dst" 2>/dev/null; } > "$dst.tmp" && mv "$dst.tmp" "$dst"
  fi
}

CMD_MD="$HOME/.claude/CLAUDE.md"
BLOCK_SRC="$PERMA/runtime/claude-md-block.md"
if _perma_block_merge "$CMD_MD" "$BLOCK_SRC"; then
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
  _perma_block_merge "$dst" "$AGENTS_BLOCK_SRC" && echo "  AGENTS.md: Permanence block refreshed at $dst"
}
merge_agents_block "$HOME/.config/agents/AGENTS.md"                 # emerging unifying standard — always
[ -d "$HOME/.codex" ]   && merge_agents_block "$HOME/.codex/AGENTS.md"    # OpenAI Codex, if installed
[ -d "$HOME/.factory" ] && merge_agents_block "$HOME/.factory/AGENTS.md" # droid, if installed
[ -f "$HOME/.config/AGENTS.md" ] && merge_agents_block "$HOME/.config/AGENTS.md"  # Amp, if it already exists
# Devin's and Google Antigravity's own global-config paths weren't confirmed at time of writing —
# verify and add here before relying on automatic Tier 2 coverage for those specifically; until
# then they fall back to the manual pointer (see docs/TOOL-SUPPORT.md).

# 5. settings.json: safely MERGE the SessionStart hook + ~/permanence permission
#    (add only if absent; preserve everything else; back up before writing).
SETTINGS="$HOME/.claude/settings.json"
if command -v python3 >/dev/null 2>&1; then
  if ! python3 - "$SETTINGS" "$PERMA" <<'PY'
import json, sys, os, shutil
path, perma = sys.argv[1], sys.argv[2]
os.makedirs(os.path.dirname(path), exist_ok=True)
data = {}
if os.path.exists(path):
    try:
        data = json.load(open(path))
    except Exception:
        print("  settings.json: present but unparseable — NOT touched. Add the hook + permission by hand.")
        sys.exit(1)
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
  then
    echo "  settings.json: FAILED to configure automatically — add the hook + permission by hand (see message above)"
    INSTALL_FAILED=1
  fi
else
  cat <<SETTINGS
  settings.json: python3 not found — add these by hand to ~/.claude/settings.json (MERGE, don't overwrite):
      "permissions": { "additionalDirectories": ["$PERMA"] },
      "hooks": {
        "SessionStart": [ { "hooks": [ { "type": "command", "command": "$PERMA/runtime/session-start.sh", "timeout": 10 } ] } ],
        "UserPromptSubmit": [ { "hooks": [ { "type": "command", "command": "$PERMA/runtime/session-load.sh", "timeout": 10 } ] } ]
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

if [ "$INSTALL_FAILED" -eq 0 ]; then
  echo "done."
else
  echo "done, WITH FAILURES — see the lines above marked FAILED. Fix those, then re-run install.sh (safe to re-run any time)."
fi
