#!/usr/bin/env bash
# update.sh — the mechanical engine behind /perma-upgrade: tag-aware dry-run diff + conflict
# detection, then (only with --apply) refresh Permanence's MACHINERY from the template repo.
# Leaves your personal streams + registry + notes untouched, always.
#
# ONE-TIME SETUP: put your template git URL in ~/permanence/runtime/.update-source (already
# pre-filled if you cloned the public template) — or export PERMA_UPDATE_SOURCE.
#
# Usage:
#   update.sh              # dry-run (default): show what would change, exit 0, no writes
#   update.sh --apply      # fetch + apply the non-conflicted machinery changes, commit, bump VERSION
#
# It only ever touches machinery paths (runtime/, .githooks/, templates/, SPEC/README/QUICKSTART/
# CHANGELOG); it never touches your streams, _meta/REGISTRY, design notes, or gitignored runtime
# state (logs, search index, events outbox). A clean apply is committed to your Permanence's own
# git history (so it's revertable) and updates _meta/VERSION.
#
# Conflict detection: a machinery file is flagged, not overwritten, if YOUR history has touched it
# since the version recorded in _meta/VERSION — i.e. you customized it. /perma-upgrade negotiates
# those; this script only ever applies the clean paths.
#
# Migration notes (CHANGELOG.md sections that may need stream-content changes, not just machinery)
# are deliberately NOT parsed here — reading and proposing those against your actual streams needs
# judgment, which is /perma-upgrade's job, not this script's.
set -uo pipefail
PERMA="${PERMA_DIR:-$HOME/permanence}"
BRANCH="${PERMA_UPDATE_BRANCH:-main}"
SRC="${PERMA_UPDATE_SOURCE:-$(tr -d '[:space:]' < "$PERMA/runtime/.update-source" 2>/dev/null)}"
MODE="dry-run"
[ "${1:-}" = "--apply" ] && MODE="apply"

[ -n "$SRC" ] || { echo "No update source set. Put your template git URL in $PERMA/runtime/.update-source (or export PERMA_UPDATE_SOURCE)."; exit 1; }
git -C "$PERMA" rev-parse --git-dir >/dev/null 2>&1 || { echo "$PERMA is not a git repo."; exit 1; }
if [ "$MODE" = "apply" ] && { ! git -C "$PERMA" diff --quiet || ! git -C "$PERMA" diff --cached --quiet; }; then
  echo "Your Permanence has uncommitted changes — commit or stash them first, then re-run --apply (so the machinery update lands cleanly)."
  exit 1
fi

PATHS=(runtime .githooks templates SPEC.md README.md QUICKSTART.md CHANGELOG.md)   # machinery only
CURRENT=$(tr -d '[:space:]' < "$PERMA/_meta/VERSION" 2>/dev/null || echo "")
[ -n "$CURRENT" ] || CURRENT="unknown"

echo "fetching from $SRC ($BRANCH) ..."
git -C "$PERMA" remote get-url _machinery >/dev/null 2>&1 \
  && git -C "$PERMA" remote set-url _machinery "$SRC" \
  || git -C "$PERMA" remote add _machinery "$SRC"
git -C "$PERMA" fetch -q --tags _machinery "$BRANCH" || { echo "Fetch failed — check the URL/branch and your access to the repo."; exit 1; }

LATEST_TAG=$(git -C "$PERMA" tag --merged FETCH_HEAD --sort=-v:refname 2>/dev/null | head -1)
TARGET="${LATEST_TAG:-FETCH_HEAD}"
echo "installed: $CURRENT  →  latest: ${LATEST_TAG:-"(untagged, using $BRANCH HEAD)"}"

if [ -n "$LATEST_TAG" ] && [ "$CURRENT" = "$LATEST_TAG" ]; then
  echo "Already up to date."
  exit 0
fi

echo ""
echo "Changed machinery files (HEAD..$TARGET):"
CHANGED=$(git -C "$PERMA" diff --name-status HEAD "$TARGET" -- "${PATHS[@]}" 2>/dev/null)
if [ -z "$CHANGED" ]; then
  echo "  (none)"
else
  echo "$CHANGED" | sed 's/^/  /'
fi

# --- conflict detection: did YOUR history touch a changed path since your recorded version? ---
CONFLICTS=()
if [ "$CURRENT" != "unknown" ] && git -C "$PERMA" rev-parse -q --verify "$CURRENT" >/dev/null 2>&1; then
  while IFS=$'\t' read -r _ path; do
    [ -n "${path:-}" ] || continue
    if ! git -C "$PERMA" diff --quiet "$CURRENT" HEAD -- "$path" 2>/dev/null; then
      CONFLICTS+=("$path")
    fi
  done <<< "$CHANGED"
else
  [ "$CURRENT" = "unknown" ] || echo "  (note: recorded version $CURRENT isn't a known ref here — skipping customization check)"
fi

if [ "${#CONFLICTS[@]}" -gt 0 ]; then
  echo ""
  echo "⚠️  You've customized ${#CONFLICTS[@]} file(s) the template also changed — these need a decision, not a blind overwrite:"
  printf '  %s\n' "${CONFLICTS[@]}"
fi

if git -C "$PERMA" diff --name-only HEAD "$TARGET" -- CHANGELOG.md 2>/dev/null | grep -q .; then
  echo ""
  echo "📋 CHANGELOG.md changed in this range — check it for a Migration notes section before applying."
fi

if [ "$MODE" = "dry-run" ]; then
  echo ""
  echo "Dry run only — nothing changed. Re-run with --apply to fetch and commit the non-conflicted machinery changes."
  exit 0
fi

# --- apply: only the non-conflicted paths; conflicted ones are left for /perma-upgrade to negotiate ---
APPLY_PATHS=()
for p in "${PATHS[@]}"; do
  skip=false
  for c in "${CONFLICTS[@]:-}"; do
    case "$c" in "$p"*) skip=true; break ;; esac
  done
  $skip || APPLY_PATHS+=("$p")
done

git -C "$PERMA" checkout -q "$TARGET" -- "${APPLY_PATHS[@]}" 2>/dev/null || true
chmod +x "$PERMA/runtime/"*.sh "$PERMA/.githooks/"* 2>/dev/null
echo "re-running install.sh (re-wires hooks + commands) ..."
bash "$PERMA/runtime/install.sh"
mkdir -p "$PERMA/_meta"
printf '%s' "${LATEST_TAG:-$TARGET}" > "$PERMA/_meta/VERSION"
git -C "$PERMA" add "${APPLY_PATHS[@]}" "$PERMA/_meta/VERSION" 2>/dev/null

if git -C "$PERMA" diff --cached --quiet; then
  echo "Already up to date — no machinery changes."
else
  git -C "$PERMA" commit -q -m "perma-upgrade: machinery refreshed to ${LATEST_TAG:-$TARGET} ($SRC)"
  echo "✅ Machinery updated to ${LATEST_TAG:-$TARGET} and committed; your streams are untouched. Start a fresh session so the new hooks load."
fi
if [ "${#CONFLICTS[@]}" -gt 0 ]; then
  echo ""
  echo "⚠️  ${#CONFLICTS[@]} customized file(s) left untouched (see above) — resolve them with /perma-upgrade."
fi
