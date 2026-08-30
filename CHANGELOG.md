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

## [1.0.3] — fixes from an Axis Engineering Two-Pass review

A Two-Pass review (`axis/runs/2026-08-30-object-permanence-two-pass/`) found 29
issues in the machinery; this release fixes everything through P2 (19 of them).
No migration notes — nothing here requires a stream to change shape, and every
fix degrades safely for an already-configured install (see the review's own
synthesis for exactly what changed and why).

**P0 — data loss / scope escapes:**
- `install.sh` and `migrate-from-brain.sh` could silently delete everything
  after a `<!-- perma:begin -->` marker in `~/.claude/CLAUDE.md` or a global
  `AGENTS.md` file if the matching end marker was missing or malformed, with
  no backup. Both now verify the marker pair before touching the file, and
  back up first.
- The unattended nightly consolidate held an unscoped `Write` tool despite
  `SPEC.md` documenting the pass as read-only. Scoped to `.consolidation/*`.
- `make-backup.sh` could report a verified success while silently omitting
  uncommitted notes, then prune the previous (actually complete) backup. It
  now checks the tree is clean first, says so loudly if not, and skips
  pruning on an incomplete run.

**P1:**
- `install.sh` could report `done.` after a real failure (an unparseable
  `settings.json`, a failed command copy) — now tracks and reports failures.
- `migrate-from-brain.sh`'s machinery refresh could delete uncommitted local
  edits with no warning — now requires a clean tree first.
- A stale `.perma-lock` (left behind by a crashed review) silently disabled
  the nightly job forever — now ages out with a loud alert past 4 hours.
- `update.sh`'s conflict detection matched by directory prefix, so one
  customized file under `runtime/` excluded the *entire* directory — ~20
  scripts — from an upgrade, and could bump `_meta/VERSION` anyway, hiding
  the gap from every future run. Now matches per file, and only advances
  `VERSION` when nothing was left conflicted. Also fixed a real bash-3.2
  (macOS's `/bin/bash`) crash on an all-conflicted upgrade.
- `_meta/REGISTRY.md` rows with a trailing slash matched nothing; rows
  missing a leading `|` were silently dropped. `resolve-stream.sh` now
  normalizes trailing slashes and validates row shape; `session-start.sh`'s
  own duplicate copy of this parser is gone — it calls the shared script.
- A space in `$HOME` (e.g. `/Users/Anna Smith`) broke every scheduled job
  silently — the generated command re-parses as a second shell command line
  when the job fires, and an unquoted path there word-splits on the space.

**P2:**
- `session-start.sh` and `session-load.sh` resolved "the current workspace"
  two different ways and could disagree under a symlink — both now read the
  same hook-provided `cwd`.
- The pre-commit people-rule guard exempted *every* `README.md`, including a
  stream's own (a canonical file that can hold real content about real
  people) — narrowed to just this repo's own top-level README. A git-quoted
  path header (non-ASCII filenames) silently skipped the whole file — now
  handled. Three benign false positives narrowed.
- `generate-contents.sh` used BSD-only `stat -f`, breaking silently on
  Linux — now tries BSD then GNU.
- The generated launchd plist embedded the scheduled command unescaped;
  `plutil -lint` rejected it. Now XML-escaped.
- `session-load.sh` never set its once-per-session marker without `python3`,
  so the auto-load text repeated on every prompt instead of just the first.
  Now has a non-Python fallback.
- A filename with a space broke `post-commit`'s search-index update via a
  bare `xargs` — now null-delimited throughout.
- The cognitive-debt scan shipped scheduled weekly by default against a
  placeholder watch-list, contradicting its own "opt-in" docs, and could
  silently misreport (or emit false breach events) if pointed at something
  real but non-Python. Now refuses to run unconfigured, and `install.sh`
  only schedules it once it's actually set up. Also fixed an unescaped-JSON
  embedding that let a hostile git commit author name run arbitrary Python
  inside the scan.
- `make-backup.sh` — the only implementation of the custody invariant — was
  referenced by nothing in the documented setup flow; added to QUICKSTART.
- `SPEC.md`'s invariant 5 claimed lock-fencing and worktree-isolation as
  mechanical guarantees; they are conventions the model follows via prompted
  steps, not code that enforces them. Reworded to say so.

**Deliberately not done in this release:** F20 (stream discovery is
implemented three slightly different ways across `perma-help.sh`,
`perma-brief.md`, and `generate-contents.sh`) needs an actual design
decision on the one shared definition, not a mechanical fix — left for a
follow-up.

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
