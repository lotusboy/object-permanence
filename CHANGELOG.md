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

## [1.0.2] — scheduled tasks can't be hijacked by a second install

Both changes are in `runtime/schedule-task.sh`. No migration notes; existing
installs keep their scheduled jobs exactly as they are.

- **Ownership guard.** A scheduled task's identifier is built from the task name
  and your username, not the install path — deliberately, because one Permanence
  per machine is the intended model and a stable identifier is what makes a
  re-install replace its own job instead of piling up duplicates. The cost was
  that a *second* Permanence on the same machine (most often a test install)
  silently took over the first one's job and repointed it at the wrong directory,
  printing nothing to say so. `schedule_task` and `unschedule_task` now check
  which Permanence an existing job actually runs from and leave it alone if it
  belongs to a different one, explaining what they found and why they stopped.
  Re-installing over your own job is unchanged.
- **Scheduling now says where the job will run from.** The success line named the
  task but not the directory, so a takeover would have been invisible even to
  someone reading the output closely.

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
