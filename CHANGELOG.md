# Changelog

Releases of Permanence **machinery** — `runtime/`, `.githooks/`, `templates/`, and the
docs. Your own streams, `_meta/REGISTRY.md`, and notes are never part of a release;
they're yours, not the template's.

Tagged `vMAJOR.MINOR.PATCH`. `/perma-upgrade` diffs your installed version (recorded
in `_meta/VERSION`) against the latest tag here and walks you through what changed.

A release entry gets a **Migration notes** section only when it changes something
that existing streams may need to adapt to (a `SPEC.md` convention, a canonical file's
expected shape). No section = nothing for your streams to do; `/perma-upgrade` just
refreshes machinery as usual. Migration notes are read and *proposed* against your
streams, never applied without your say-so (SPEC.md invariant 5).

## [Unreleased]

## [1.0.1] — installable from GitHub

Documentation and one bug fix. No change to how the machinery behaves, and nothing
for existing streams to adapt to.

- **README**: an install section near the top, with the real clone URL. Two routes —
  hand your AI the repo URL and one instruction, or run three commands yourself.
  Previously the only onboarding note assumed you had been sent a zip, so someone
  finding the repo on GitHub had no stated way in.
- **README + QUICKSTART**: say plainly that the repo is named `object-permanence`
  while the install directory is `~/permanence`, so the clone command names its
  target explicitly instead of landing in the wrong folder. Explain why `.git` is
  discarded and re-initialised, and note that `/perma-upgrade` still works
  afterwards because the upstream URL lives in `runtime/.update-source`.
- **QUICKSTART**: replaced the unusable `git clone <your fork>` placeholder.
- **Install**: both documented paths now make an initial commit. Without one,
  `install.sh` stamped every command `unversioned` and the git hooks never armed.
- **Fix** (`runtime/install.sh`): the fallback printed when `python3` is missing
  hardcoded `$HOME/permanence` in its settings snippet, ignoring `PERMA_DIR`, while
  the main path honoured it.

## [1.0.0] — first public release

Baseline: streams (`PROJECT`/`LOG`/`PEOPLE`/`QUESTIONS`), the four conventions,
`/perma-*` commands, `/perma-upgrade`, opt-in events/search/cognitive-debt-scan,
programme groups. No migration notes — this is the starting point.
