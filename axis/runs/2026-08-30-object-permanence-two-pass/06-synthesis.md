# Synthesis — Pass 1 (Analytical) + Pass 2 (Adversarial) Merged

Reconciled from `04-pass1-output.md` and `05-pass2-output.md` only. The repository itself was not
re-read for this step; every citation below is carried forward from one or both pass reports as
written. Where a citation looked suspicious, that is noted rather than checked.

## 1. Header table

| Field | Value |
|---|---|
| Date | 2026-08-30 |
| Target | `/Users/lotusboy/workspaces/object-permanence` @ `680e3d5` (Pass 1's stated commit; Pass 2 did not restate a commit) |
| Pass 1 finding count | 22 (FP 4 · M 7 · G 11) |
| Pass 2 finding count | 19 (PM 5 · Chaos 9 · PY 5) |
| Merged count | **29** — P0: 3 · P1: 6 · P2: 11 · P3: 9 |
| Andon status | **Triggered.** 3 P0 findings, all data-loss or unattended-write mechanisms. Two (install.sh truncation; nightly-consolidate's unrestricted Write) were raised independently by both passes. One (make-backup.sh's false-success/prune) is Pass 2's own live-execution finding, with Pass 1 having independently logged the same underlying fact as a supporting detail inside a different, lower-severity finding. |
| Convergence rate | 8 / 29 = **28%** (findings raised independently by both passes, on the same artefact and root cause, before this merge) |

## 2. Verdict

**Not safe for an unsupervised stranger to install today, but the fix list is short and mostly
mechanical.** Both passes, working independently, converged on the same two facts: `install.sh`
can silently destroy the tail of a config file it does not own (`~/.claude/CLAUDE.md` and four
`AGENTS.md` paths) with no backup, and the nightly unattended Claude run holds an unscoped `Write`
tool while the project's own docs and code comments call the pass "read-only by construction."
Pass 2 additionally caught, by actually running it against the live install, that the one script
meant to make a user's notes recoverable (`make-backup.sh`) reports a verified success while
silently excluding anything not yet committed, then deletes the previous (good) backup — Pass 1
had logged the same underlying fact (backup is committed-history-only) but filed it as a footnote
under a different finding (the script's undiscoverability) rather than as a severity-worthy risk
in its own right. Stacked, these three are not one narrow bug but three independent ways ordinary,
non-adversarial use loses data or grants an unattended agent more reach than documented. None of
this requires an architecture change — the fixes are quoting, path-scoping, pre-flight checks, and
a backup-before-overwrite, on a handful of scripts. Until those land, this is "safe with caveats
for a technical user who has read the scripts," not "safe to hand a stranger."

## 3. Findings

Severity: P0 (Andon — data loss, or breaking a tool other than Permanence) → P3.

### P0

**F01 — `install.sh` (and `migrate-from-brain.sh`) can silently truncate config files they don't own, with no backup.**
Origin: **both passes, independently** — Pass 1 G-1 (Andon item), Pass 2 PM-3 (P0, self-labelled).
Artefact: `runtime/install.sh:42-45,63-67` (Pass 1); `runtime/install.sh:59-72` and
`runtime/migrate-from-brain.sh:86` (Pass 2, additional scope).
Symptom/failure mode: the `awk` block-merge sets `skip=1` on `<!-- perma:begin` and only clears it
on a byte-exact `<!-- perma:end -->`. If the end marker is missing or altered by one character,
everything after the begin marker in the target file is deleted. Both passes reproduced this
independently in a scratch/live test.
Root cause: an unanchored, fragile text-splice into files Permanence does not own, with no
integrity check on the marker pair and no backup taken on this path (unlike `settings.json`, which
gets a `.perma-bak` at `install.sh:112`).
Scope: Pass 1 found this against `~/.claude/CLAUDE.md` and the four `AGENTS.md` paths
(`install.sh:63-76`); Pass 2 independently confirmed the CLAUDE.md/AGENTS.md instance and added
that `migrate-from-brain.sh:86` carries the identical defect against a `brain:begin` marker — a
scope Pass 1 did not examine.
Severity: **P0** — both passes agree, and Pass 2 ran it.
Recommendation: verify the begin/end pair exists and is well-formed before touching the file;
back up the original (same pattern as the `settings.json` `.perma-bak`) before any block-merge, in
both `install.sh` and `migrate-from-brain.sh`.

**F02 — Unattended nightly Claude run holds an unscoped `Write` tool while docs and code claim "read-only."**
Origin: **both passes, independently** — Pass 1 FP-1, Pass 2 PM-2 (P0, self-labelled).
Artefact: `runtime/nightly-consolidate.sh:69-75` (grant); `SPEC.md:24` ("read-only by
construction"); `nightly-consolidate.sh:4-6` (header comment: "read access + report-write … and
nothing else").
Symptom/failure mode: `claude -p --permission-mode default --allowedTools "Read" "Glob" "Grep"
"Write" …` — every `Bash` grant is path-scoped; `Write` is not scoped to any path. A headless
`default`-mode run auto-approves anything in the allow-list with nobody present to catch an
out-of-scope write.
Root cause: the safety property ("writes only under `.consolidation/**`") is enforced by prompt
wording in `perma-consolidate.md`, not by the tool grant itself.
Severity: **P0** — both passes agree; Pass 2 additionally names the trigger path (a
prompt-injection-shaped note, since the tool reads untrusted transcripts/Slack extracts by design,
or a model error, or an edit to the command file) but did not execute a headless run to observe an
actual out-of-scope write (listed in its own "read but not run" ledger).
Recommendation: scope the grant to `Write(<PERMA>/.consolidation/**)`, which Pass 2 notes is
already supported syntax, closing the gap between the claim and the code.

**F03 — `make-backup.sh` reports a verified backup while silently excluding uncommitted notes, then deletes the previous backup.**
Origin: **primarily Pass 2** — PM-1 (P0, self-labelled), live-executed. Pass 1's FP-4 independently
recorded the same underlying fact — "`make-backup.sh:39` bundles committed history only, so
uncommitted stream edits … are absent from the backup" — but as a closing sentence inside a
different, lower-severity finding about the script being unreferenced (see F12), not scored on its
own.
Artefact: `runtime/make-backup.sh:39` (`git bundle create --all`, committed history only), `:46`
("OK … round-trip verified"), `:77` (deletes older backups).
Symptom/failure mode: Pass 2 checked the live install — `git -C ~/permanence status --porcelain`
returns 4 modified files right now (`LOG.md`, `PROJECT.md`, `QUESTIONS.md`,
`_meta/REGISTRY.md`) — and traced the scenario: skip `/perma-shutdown` or crash before it commits,
run the documented backup procedure, see "OK … round-trip verified," and the previous (actually
good) backup gets pruned. Three runs and the last real backup is unrecoverable while the tool
reported success three times.
Root cause: no pre-flight `git status --porcelain` check before bundling; no gate on pruning when
the tree isn't clean.
Severity: **P0**, per Pass 2's self-label. Pass 1's corroborating fact does not itself carry a
severity judgment, so there is no escalation call to make here — Pass 2's label stands.
Note on the two passes' framing: Pass 2's scenario describes running "the documented backup." Pass
1 separately verified by repo-wide grep (its "verified by execution" bucket) that `make-backup.sh`
is referenced by nothing — not `install.sh`, `README.md`, `QUICKSTART.md`, `SPEC.md`, or
`perma-help.sh`. This is a soft tension, not a hard contradiction (Pass 2 never claims the script
appears in those docs, and the danger holds regardless of whether a user finds it via a doc pointer
or by browsing `runtime/`), but it means F03's severity should be read alongside F12: today, a
user has to go looking for this script to be at risk from it. See §4.
Recommendation: check `git status --porcelain` before bundling; refuse or loudly warn on a dirty
tree rather than silently omitting it from the backup; don't prune the previous backup on a run
that skipped anything.

### P1

**F04 — `install.sh` prints `done.` even when a step failed or nothing was wired.**
Origin: Pass 2 only — PM-4 (P1, self-labelled).
Artefact: `runtime/install.sh:7` (`set -u` only, no `-e`, no `pipefail`); `:94` (embedded Python
`sys.exit(0)` on unparseable `settings.json`); `:152` (`done.`).
Symptom/failure mode: if `~/.claude/settings.json` is unparseable, or `cp`/`launchctl` fails, or
`python3` is missing, the script continues past the failure and reports success. Both hooks can end
up unwired while the user is told the install worked.
Root cause: no `set -e`/`pipefail`, and the Python helper exits 0 on its own failure path instead
of signalling the caller.
Severity: **P1** (Pass 2 label; Pass 1 did not examine this script's error handling).
Recommendation: `set -e -o pipefail`; make the Python helper exit non-zero on failure and check its
exit code in the shell; print a real pass/fail summary instead of an unconditional `done.`.

**F05 — `migrate-from-brain.sh` deletes machinery with no clean-tree check and no rollback.**
Origin: Pass 2 only — PM-5 (P1, self-labelled).
Artefact: `runtime/migrate-from-brain.sh:69-72` (`rm -rf "${NEW:?}/${p:?}"` across `runtime
.githooks templates SPEC.md README.md QUICKSTART.md CHANGELOG.md`, then `cp -R`).
Symptom/failure mode: the script's own comment (`:65-68`) claims this is non-destructive because
git history retains everything — true only for *committed* content. Uncommitted edits under
`templates/` are deleted with no prompt. If `cp` fails partway under `set -e`, the install is left
with `runtime/` deleted and nothing to replace it.
Root cause: no pre-check that the tree is clean (contrast `update.sh:34`, which requires one before
applying), and no staging/rollback around the delete-then-copy.
Severity: **P1** (Pass 2 label).
Recommendation: require a clean tree (or at minimum a dirty-tree warning) before the `rm -rf`
block; stage the copy before deleting the old paths, or delete only after the copy succeeds.

**F06 — A stale `.perma-lock` silently and permanently disables the nightly consolidation job.**
Origin: Pass 2 only — PY-1 (P1, self-labelled).
Artefact: `runtime/nightly-consolidate.sh:56` (`[ -f "$PERMA/.perma-lock" ] && exit 0`, no age
check, no alert).
Symptom/failure mode: the lock is taken and released only by a model following instructions in
`perma-consolidate-review.md:96,109`. A Ctrl-C, crash, or context exhaustion between those two
steps leaves the lock in place forever; the nightly job then exits 0 silently, every night,
indefinitely.
Root cause: no lock-age check, no loud failure — Pass 2 notes this directly contradicts the same
script's own stated principle 15 lines later (`:78-92`, "silent-green is worse than a loud
failure").
Severity: **P1** (Pass 2 label).
Recommendation: age the lock out after some bound, or `alert()` on a skip rather than a bare
`exit 0`.

**F07 — `update.sh`'s directory-prefix conflict matching drops entire directories from updates, and can misreport itself as current or crash.**
Origin: **both passes, independently**, on the same mechanism with different consequences —
Pass 1 G-5 (unscored) and Pass 2 C-8 (P1, self-labelled).
Artefact: `runtime/update.sh:99-105` (conflict skipping by path *prefix*), `:102`
(`case "$c" in "$p"*)`), `:112` (unconditional `VERSION` write), `:53-55` (next-run "already up to
date" short-circuit).
Symptom/failure mode — Pass 1: one customized file under `runtime/` excludes the *entire*
`runtime/` directory from the checkout, `VERSION` is bumped anyway, and the next run sees
`CURRENT = LATEST_TAG` and exits before diffing — skipped machinery never lands and is never
surfaced again. Symptom/failure mode — Pass 2 (verified by execution): the same prefix-match drops
`runtime/` entirely so all 20 scripts stop updating, the warning names only the one conflicting
file, and if every path conflicts, `APPLY_PATHS` is empty and stock macOS `/bin/bash` 3.2
(confirmed on the live machine) aborts mid-apply under `set -u` when expanding the empty array.
Root cause: the same directory-prefix conflict check in both cases.
Severity: **P1** (Pass 2's label for its half of this finding; Pass 1's independent discovery of
the same mechanism, with an additional consequence — the false "up to date" state — supports
keeping it at P1 rather than lower).
Recommendation: match conflicts per-file, not by directory prefix; quote/guard the `APPLY_PATHS`
expansion for `set -u` under bash 3.2; don't bump `VERSION` when paths were skipped.

**F08 — Registry rows are silently defeated by a trailing slash or a missing leading pipe; the parser is also duplicated, not shared.**
Origin: **both passes, independently converged on the trailing-slash case** — Pass 1 G-2 (missing
leading pipe is Pass-1-unique) and Pass 2 C-3 (P1, self-labelled, verified by execution). Pass 1's
G-3 and Pass 2's PY-4 are folded in as directly related findings on the same artefact.
Artefact: `runtime/resolve-stream.sh:15,20` (`IFS='|' read -r _ ws stream`; `case "$TARGET" in
("$ws"|"$ws"/*)`); `session-start.sh:30-39` (duplicate, unfixed copy of the same parser — G-3);
`_meta/REGISTRY.md` (unvalidated, hand-edited — PY-4).
Symptom/failure mode: a registry row whose path has a trailing slash (`/Users/me/work/proj-two/`)
matches nothing, neither the directory nor its children (Pass 1 traced this on a synthetic
registry; Pass 2 confirmed it against a live `/tmp/projA/` row and additionally observed the
session then offers to *re-register*, risking a duplicate row). Pass 1 separately found that a row
missing its leading `|` is silently dropped, because the discarded first field of the `IFS='|'`
read consumes the path. Both defects look correct to a human eye. Compounding this: `G-3` — the
comment at `resolve-stream.sh:3` claims the parser was "factored out of `session-start.sh`," but
`session-start.sh:30-39` still carries an independent, unfixed copy; every other consumer
(`session-load.sh`, `events-listen.sh`, `stop-listen.sh`, `emit-event.sh`) calls the shared script,
so a fix to the shared file would silently miss the SessionStart path.
Root cause: string-based parsing of a hand-edited file with no normalization or schema check, and
one un-migrated duplicate of the parser.
Severity: **P1** (Pass 2's label for the trailing-slash case).
Recommendation: normalize trailing slashes before comparison in one place; validate the pipe count
per row; delete the duplicate parser in `session-start.sh` and call the shared script; add the
validator Pass 2 proposes (PY-4) — a `perma-registry-check` flagging trailing slashes, relative
paths, unresolvable directories, and duplicate rows.

**F09 — `install.sh`'s scheduled-job wiring breaks silently if `$HOME` contains a space.**
Origin: Pass 2 only — C-1 (P1, self-labelled, verified by execution).
Artefact: `runtime/install.sh:32-33` (`$PERMA` interpolated unquoted into the scheduler's shell
string).
Symptom/failure mode: confirmed by running it — `bash -c` reports "`/Users/Anna: No such file or
directory`" for a home directory like `/Users/Anna Smith`. The nightly job fires every night and
does nothing; the log redirect is also broken, so nothing is written anywhere. Silent, permanent.
Root cause: unquoted variable interpolation into a generated shell command string.
Severity: **P1** (Pass 2 label).
Recommendation: quote `"$PERMA"` (and any other interpolated path) in the generated scheduler
command.

### P2

**F10 — `cogdebt-scan.sh` ships broken-by-default, scheduled always-on despite being documented as opt-in, and contains a code-injection-shaped bug.**
Origin: **both passes, independently, on the placeholder/always-on defect** — Pass 1 FP-3
(unscored) + M-4 (unscored), Pass 2 C-9 (self-labelled **P3**). The injection detail is Pass-2-only.
Artefact: `runtime/cogdebt-scan.sh:39` (placeholder watch-list, literal
`$HOME/path/to/your/ai-built-repo`), `:50` (`ls-files '*.py'`, Python-only), `:81,85` (unquoted
heredoc, `cur=json.loads('''$ALL''')`), `:48` (unescaped `$R` interpolation into the error branch);
`runtime/install.sh:33-34` (schedules it weekly on every install, and its own comment admits the
list needs editing first); `README.md:71,76,78` (lists it under "opt-in"/"deliberately off by
default"); `SPEC.md:42` (lists it as part of the fully-automated binding).
Symptom/failure mode: a default install runs a weekly job that either reports "not a git repo"
forever, or, pointed at a non-Python repo, reports `src_loc: 0`, trips both floors, and emits false
breach events into every open session (Pass 1, `:109,111,123-128`). Separately (Pass 2), a repo
path containing `'''` would inject Python into a scheduled job via the unquoted heredoc.
Root cause: the feature was documented as opt-in but wired as always-on, shipped with a placeholder
default instead of failing loudly when unconfigured, and the JSON-embedding path is unescaped.
Severity: **P2 — escalated from Pass 2's self-labelled P3.** Justification for escalation, per the
merge contract ("Pass 1 supplies evidence that justifies escalation"): Pass 1 independently found
two things Pass 2's C-9 did not — the docs/code contradiction on opt-in status (M-4), and that the
broken default doesn't just no-op, it emits false breach events into every open session (FP-3).
Combined with Pass 2's injection vector, this is more than a cosmetic default-config nit.
Recommendation: match the code to the docs (make it actually opt-in, or update the docs); fail
loudly on the placeholder path instead of silently misreporting; quote/escape the JSON embedding.

**F11 — Several SPEC.md safety guarantees (lock-fencing, worktree-isolation, most of the 8 invariants) are prose instructions to the model, not code.**
Origin: **both passes, independently, converging specifically on the lock/worktree claim** —
Pass 1 FP-2 (unscored, broad: 7 of 8 invariants have no code behind them) and Pass 2 PY-2 (P2,
self-labelled, narrow: the specific "lock-fenced, worktree-isolated" claim).
Artefact: `SPEC.md:20-27` (8 invariants); `SPEC.md:24` ("single revertable `--no-ff` envelope,
lock-fenced, worktree-isolated"); `.githooks/pre-commit:26-76` (the only mechanised invariant, #3);
`perma-consolidate-review.md:96-109` (where the lock/worktree/ratification steps live, as
instructions); `session-start.sh:15-25` (a warning, not an enforcement); `nightly-consolidate.sh:56`
(a skip, not a check).
Symptom/failure mode: Pass 1 traced all 8 invariants and found only #3 mechanised; #2 (append-only
LOG) has no check anywhere (verified by repo-wide grep); #5 (human ratification) exists only as
instructions. Pass 2 independently examined the #5 claim specifically and confirmed: no script
takes the lock, no script checks it before writing, nothing enforces the worktree — two concurrent
sessions in the same stream are unfenced.
Root cause: SPEC.md asserts mechanical guarantees that are, in the current implementation,
model-followed conventions.
Severity: **P2** (Pass 2's label for its narrower confirmation; Pass 1's broader scope doesn't add
evidence for a specific worse consequence beyond what PY-2 already states).
Recommendation: either implement the claimed guarantees in code (a real lock file checked before
write, a real worktree-isolation step) or soften SPEC.md's language to describe what's actually
enforced.

**F12 — `make-backup.sh` (the only implementation of invariant 7) is referenced by nothing.**
Origin: Pass 1 only — FP-4 (unscored; primary claim, distinct from the backup-safety issue at F03).
Artefact: `runtime/make-backup.sh` — checked against `install.sh`, `README.md`, `QUICKSTART.md`,
`SPEC.md`, `perma-help.sh`, and "any command" via repo-wide grep (Pass 1's own "verified by
execution" bucket).
Symptom/failure mode: a user following the documented path never learns the script exists, so
`SPEC.md:26`'s custody invariant is unimplemented in practice.
Root cause: the script was built but never wired into the documented install/usage flow.
Severity: **P2** (my assignment — real functional gap in a documented invariant, but not itself an
active-danger trigger the way F03 is; see F03's note on the interaction between these two).
Recommendation: reference it from `QUICKSTART.md` or a `/perma-backup`-style command; once wired,
apply F03's fix (clean-tree check) before pointing users at it.

**F13 — Pre-commit people-guard exempts README.md, fails open on quoted path headers, and false-positives on benign engineering language.**
Origin: **both passes, independently converged on the README exemption**; the quoting bug and the
false-positive examples are Pass-2-only. Pass 1 G-9 (unscored), Pass 2 PY-3 (P2, self-labelled).
Artefact: `.githooks/pre-commit:51-56` (header parsing), `:61` (README exemption).
Symptom/failure mode — convergent (G-9/PY-3): the guard skips `README.md|*/README.md`; Pass 1
verified identical breaching text was flagged in `stream/PEOPLE.md` and not flagged in
`stream/README.md`, yet `SPEC.md:11` lists `README.md` as a canonical per-stream file. Pass-2-only
additions: a git-quoted path header (`+++ "b/…"`, emitted for non-ASCII filenames) falls through to
a branch that sets `file=""`, silently skipping every added line in that file with no notice; and
Pass 2 ran three benign sentences through the patterns — "the vendor API docs are dishonest about
rate limits," "idempotent by nature," "the retry logic was incompetent" — and all three blocked the
commit.
Root cause: a lexical heuristic with an unjustified file exemption and header-parsing that doesn't
handle quoted paths, plus overly broad trigger words.
Severity: **P2** (Pass 2 label).
Recommendation: remove or justify the README exemption; handle quoted `+++` headers; narrow the
trigger patterns or add a documented override, since Pass 2's read is that a guard that both misses
real breaches and blocks normal notes trains users into habitual `--no-verify`.

**F14 — `generate-contents.sh` uses BSD-only `stat -f`; breaks silently on Linux/WSL.**
Origin: **both passes, independently, identical finding** — Pass 1 G-7 (unscored), Pass 2 C-7 (P2,
self-labelled).
Artefact: `runtime/generate-contents.sh:27,41,47` (both passes cite the same three lines).
Symptom/failure mode: `stat -f '%m'` / `stat -f '%Sm'` is BSD syntax; on GNU `stat`, `-f` means
"filesystem status" and yields nothing. `post-commit:5` swallows the failure
(`2>/dev/null || true`). The inventory renders with blank dates in arbitrary order, silently.
Root cause: platform-specific `stat` flag with no portability shim, against `QUICKSTART.md:32`'s
"works on macOS and Linux with no changes" and `schedule-task.sh`'s shipped Linux backend.
Severity: **P2** (Pass 2 label).
Recommendation: use a portable date-mtime approach (e.g. `git log -1 --format=%ct`, or detect
platform and branch on `stat` flavor).

**F15 — `schedule-task.sh` embeds the command string into plist XML unescaped.**
Origin: Pass 2 only — C-2 (P2, self-labelled, verified by execution).
Artefact: `runtime/schedule-task.sh:134` (`<string>` with no XML escaping of `$command`).
Symptom/failure mode: verified on the live install — `plutil -lint` reports "unknown
ampersand-escape sequence" on both installed plists (any command containing the default `2>&1`
trips this). `launchd` currently tolerates it, but the file is malformed XML.
Root cause: no escaping of user-supplied/generated command text before XML interpolation.
Severity: **P2** (Pass 2 label).
Recommendation: XML-escape the command string before embedding it in the plist.

**F16 — `session-start.sh` and `session-load.sh` diverge on cwd under a symlinked workspace, giving contradictory registration status in the same session.**
Origin: **Pass 2 finding that resolves a question Pass 1 left explicitly open**, not a strict
convergence. Pass 1 listed this exact mechanism in its Unknown ledger ("Whether Claude Code sets
the hook process's cwd to the workspace … the difference matters but I cannot test the harness").
Pass 2's C-4 (P2, self-labelled) executed it.
Artefact: `session-start.sh:9` (`pwd -P`, physical path); `session-load.sh:13-19` (hook JSON's
logical `cwd`).
Symptom/failure mode: verified by execution — the same session gets contradictory instructions:
session-start says "this workspace is NOT registered," session-load says "this workspace is the
acme/linked stream, read it."
Root cause: two different code paths resolve "current workspace" two different ways (physical vs.
logical path) and can disagree under a symlink.
Severity: **P2** (Pass 2 label).
Recommendation: pick one cwd-resolution strategy and share it between both hook scripts (this also
overlaps with F08's "shared vs. duplicated resolver" theme).

**F17 — `session-load.sh` never marks a session loaded if `python3` is absent; the auto-load text repeats on every prompt.**
Origin: Pass 2 only — C-5 (P2, self-labelled).
Artefact: `runtime/session-load.sh:13-18,23` (`SID`/`CWD` computed via Python; falls to `nosid` if
absent, so the once-per-session marker at `:23` never applies).
Symptom/failure mode: the auto-load paragraph is injected into every prompt of every session,
permanently, rather than once.
Root cause: a hard dependency on `python3` for session identity with no fallback.
Severity: **P2** (Pass 2 label).
Recommendation: add a non-Python fallback for session/cwd identification, or fail loudly if
`python3` is missing rather than degrading to `nosid`.

**F18 — Filenames containing spaces break `post-commit`'s pipe into `perma-search`, leaving the index silently stale.**
Origin: Pass 2 only — C-6 (P2, self-labelled, verified by execution).
Artefact: `.githooks/post-commit:14-15` (bare `xargs`).
Symptom/failure mode: verified — a path like `LOG 2026.md` splits into two arguments; `perma-search
update` (`perma-search.py:200-207`) finds neither, deletes nothing, re-adds nothing. Backgrounded to
`/dev/null`, so `/perma-search` silently returns stale content indefinitely, with no error surfaced
anywhere.
Root cause: `xargs` without null-delimiting/quoting for filenames with spaces.
Severity: **P2** (Pass 2 label).
Recommendation: use `git diff -z` / `xargs -0` (or quote/read line-by-line) through this pipeline.

**F19 — `update.sh`'s "never silently overwritten" guarantee fails when `_meta/VERSION` is missing.**
Origin: Pass 1 only — G-6 (unscored).
Artefact: `runtime/update.sh:69` (conflict detection runs only if `$CURRENT` resolves as a ref),
`:77` (warning suppressed when `CURRENT="unknown"`), `:107` (checks out every machinery path —
`README.md`, `SPEC.md`, all of `runtime/` — when conflict detection was skipped); `SPEC.md:38`
("negotiated per file, never silently overwritten").
Symptom/failure mode: if `_meta/VERSION` is missing, `CURRENT` resolves to `"unknown"`, the
conflict-detection branch is skipped entirely, `CONFLICTS` stays empty, and the checkout proceeds
over the user's customizations with no warning — contradicting the stated guarantee.
Root cause: conflict detection is gated on `VERSION` existing and being a valid ref, with no
fallback path when it isn't.
Severity: **P2** (my assignment — real breach of a stated guarantee, tempered by Pass 1's own note
that it's recoverable via git, just unannounced).
Recommendation: treat a missing/invalid `VERSION` as "conflict-detection unavailable, refuse to
overwrite" rather than "no conflicts, proceed." Relates to F07 — both are gaps in the same
conflict/versioning subsystem and could plausibly be fixed together.

**F20 — Stream discovery is implemented three different ways with three different rules.**
Origin: Pass 1 only — M-2 (unscored).
Artefact: `SPEC.md:12` (a stream exists iff it has a `PROJECT.md`); `generate-contents.sh:55`
(unbounded search); `perma-help.sh:164` (`-mindepth 2 -maxdepth 3`); `perma-brief.md:9`
(hard-codes `<customer>/<project>`); `perma-register.md:19` (explicitly permits a bare `<slug>`
stream).
Symptom/failure mode: a stream nested three levels deep is indexed by the unbounded search but
invisible to the morning brief and the help counter, which both cap depth differently.
Root cause: the same "what counts as a stream" question is answered by four different
hard-coded rules instead of one shared definition.
Severity: **P2** (my assignment — concrete, demonstrated inconsistency with a real functional
consequence for some registered streams).
Recommendation: centralize stream discovery into one function/script (mirroring the
`resolve-stream.sh` pattern) that all four consumers call.

### P3

**F21 — `session-start.sh` instructs reading a stream directory with no existence check.**
Origin: Pass 1 only — G-4 (unscored).
Artefact: `session-start.sh:61-64` (builds `STREAM_DIR`, instructs the read, no directory-exists
test).
Symptom/failure mode: a renamed or deleted stream yields a confident "read these files now" for
files that aren't there.
Root cause: missing existence check before emitting the read instruction.
Severity: **P3** (my assignment — narrow blast radius; a nonexistent-file read is a low-cost
failure mode for the model to recover from on its own).
Recommendation: test the directory exists before emitting the instruction; say so plainly if not.

**F22 — Event delivery is keyed to the stream, not the session; a second concurrent session misses events.**
Origin: Pass 1 only — G-11 (unscored). Loosely related to, but distinct from, an item in Pass 2's
own Unknown ledger (cursor-write-before-delivery ordering in the same files, a race Pass 2 read but
did not reproduce) — not a convergence, just adjacent territory in the same scripts.
Artefact: `events-listen.sh:24-31`, `stop-listen.sh:36-40` (one cursor file per stream, advanced to
line count on every run); `install.sh:136` ("delivered exactly once").
Symptom/failure mode: two sessions open on the same workspace — the first to fire consumes the
event, the second never sees it. The "exactly once" claim holds across the two hook types, not
across concurrent sessions.
Root cause: cursor keyed by stream rather than by (stream, session).
Severity: **P3** (my assignment — real but narrow, single-user-with-two-sessions scenario, no data
loss, just a missed notification).
Recommendation: key the cursor by session where feasible, or document the "first session wins" 
behavior explicitly.

**F23 — Install-family scripts lack the dry-run/backup/uninstall safety net `update.sh` has.**
Origin: **loosely related, not a strict dedupe** — Pass 1 M-7 (unscored, broader: no uninstall path
for any of the 5 machine-wide writes) and Pass 2 PY-5 (P3, self-labelled, narrower: no dry-run or
backup specifically for `migrate-from-brain.sh` and `install.sh`'s unowned-file writes).
Artefact: `update.sh:29` (dry-run by default, contrast case); `migrate-from-brain.sh` (`rm -rf` ×7
paths, no dry-run); `install.sh` (writes 4 unowned files + 2 scheduled jobs, no inverse);
`shutdown-nudge.sh:40` (the only existing uninstall-adjacent path, per Pass 1).
Symptom/failure mode: no way to preview or reverse what `install.sh` or `migrate-from-brain.sh` will
do before it happens.
Root cause: `update.sh` was built with a dry-run default; the other two scripts in the same family
weren't.
Severity: **P3** (Pass 2's label; Pass 1's broader framing doesn't add stronger-consequence
evidence to escalate).
Recommendation: add a `--dry-run` to `migrate-from-brain.sh` and `install.sh`, and a documented
uninstall path.

**F24 — Context-load paths overlap; CLAUDE.md is installed even where the SessionStart hook already fires, despite being documented as a "fallback."**
Origin: Pass 1 only — M-1 (unscored).
Artefact: `install.sh:100-103` (SessionStart hook), `:107-110` (UserPromptSubmit `session-load`
hook), `:37-50` (CLAUDE.md block write), `:73` (unconditional `~/.config/agents/AGENTS.md` write);
`claude-md-block.md:2` ("fallback for environments without SessionStart hooks").
Symptom/failure mode: in Tier-1 Claude Code, at least three paths instruct the same load, one of
them telling the model to shell out to `session-start.sh` a second time.
Root cause: the CLAUDE.md fallback block is installed unconditionally, not gated on whether the
SessionStart hook is actually active.
Severity: **P3** (my assignment — redundancy/waste, not a correctness break).
Recommendation: gate the CLAUDE.md block write on hook availability, or accept the redundancy
explicitly in the docs.

**F25 — REGISTRY/GROUPS resolution logic is duplicated across code, prose, and a third ad-hoc parser.**
Origin: Pass 1 only — M-3 (unscored).
Artefact: `resolve-stream.sh` (code, for streams); `perma-shutdown.md:15` ("longest-prefix match on
cwd, same as the registry" — prose, for groups); `perma-help.sh:128-145` (a third, ad-hoc Python
parser).
Symptom/failure mode: there is no `resolve-group.sh`; the group lookup's correctness depends on a
model re-deriving prefix matching by hand each time it's needed.
Root cause: the group-resolution logic was never factored into a shared script the way stream
resolution was.
Severity: **P3** (my assignment — fragility/maintainability concern; no concrete failure
demonstrated, unlike F20's stream-discovery case).
Recommendation: write `resolve-group.sh` mirroring `resolve-stream.sh`, and point all three
consumers at it.

**F26 — `SPEC.md` is behind the implementation in two places.**
Origin: Pass 1 only — M-5 (unscored).
Artefact: `SPEC.md §3:33-38` and `:42` (six triggers and the binding paragraph never mention
`session-load.sh`/UserPromptSubmit, which `README.md:64` calls "the *reliable* trigger," nor the
events bus, nor search); `SPEC.md:42` (still instructs adding two `settings.json` entries manually,
which `install.sh:97-114` now merges automatically).
Symptom/failure mode: the harness-independent contract — meant as the rebuild instruction for
another agent — omits the load-bearing read path and describes a manual step that's now automated.
Root cause: documentation drift as the implementation grew past the spec.
Severity: **P3** (my assignment — documentation debt, no runtime consequence).
Recommendation: update `SPEC.md §3` to include the UserPromptSubmit path, events bus, and search;
remove the now-automated manual settings.json instruction.

**F27 — `templates/` doesn't ship all six canonical files `SPEC.md` names.**
Origin: Pass 1 only — M-6 (unscored).
Artefact: `SPEC.md:11` (six canonical stream files); `templates/` (ships four — no `STRATEGY.md`, no
stream `README.md`); `README.md:88` ("blank skeletons for the canonical files");
`session-start.sh:63` (never asks for the stream's `README.md`, despite `SPEC.md:11` calling it
orientation).
Symptom/failure mode: a new stream created from `templates/` is missing two of its own canonical
files by default.
Root cause: `templates/` was not kept in sync with `SPEC.md`'s canonical-file list.
Severity: **P3** (my assignment — setup completeness gap, not a runtime break).
Recommendation: add `STRATEGY.md` and a stream `README.md` template; have `session-start.sh` read
the stream's `README.md` per `SPEC.md:11`.

**F28 — `schedule-task.sh`'s header comment understates its own CI test coverage.**
Origin: Pass 1 only — G-8 (unscored).
Artefact: `schedule-task.sh:8-10` ("could not be run-tested" for Linux/Windows backends);
`ci.yml:100-159` (runs `install.sh` on ubuntu/macos/windows, asserts real cron/launchd/schtasks
entries exist and unschedule cleanly).
Symptom/failure mode: none — this is a documentation-accuracy nit in the opposite direction from
most findings here (the comment is more pessimistic than the evidence supports).
Root cause: the comment predates the CI matrix and was never updated.
Severity: **P3** (my assignment — cosmetic; flagged because Pass 1 verified it, not because it
poses any risk).
Recommendation: update the comment to reflect actual CI coverage.

**F29 — Three references to `_meta/generative-orchestration-pass.md`, a file that doesn't ship.**
Origin: Pass 1 only — G-10 (unscored).
Artefact: `SPEC.md:37`, `SPEC.md:40`, `.githooks/post-commit:20` — all cite this file as rationale
for a deliberately-unbuilt feature; it is absent from the repo (verified by Pass 1). CI's link
checker (`ci.yml:23-38`) doesn't catch it because it's a bare path, not a Markdown link.
Symptom/failure mode: a dangling reference to nonexistent scaffolding, invisible to the existing
link check.
Root cause: doc/comment references written ahead of the file being built, never removed or the
gate never having caught it.
Severity: **P3** (my assignment — doc hygiene).
Recommendation: either build the referenced file, or replace the references with a note that the
feature is deliberately not yet implemented; consider extending the link checker to catch bare
paths.

## 4. Conflicts and disagreements

**No hard contradictions.** Across 41 raw findings between the two passes, we found one soft
tension worth flagging and one place where Pass 2 resolved a question Pass 1 had explicitly left
open — neither is a case of one pass asserting X where the other asserts not-X.

- **Soft tension (F03 / F12, `make-backup.sh`).** Pass 1's FP-4 verified by repo-wide grep that
  `make-backup.sh` is referenced by nothing in the documented install/usage path. Pass 2's PM-1
  describes a user who "runs the documented backup" and walks into the false-success/prune
  scenario. These aren't strictly incompatible — Pass 2 never claims the script appears in
  README/QUICKSTART, and a user could reach it by browsing `runtime/` regardless of whether it's
  "documented" in the sense Pass 1 checked — but the framing differs enough that we flag it rather
  than silently merge the two into one severity number. We kept them as separate findings (F03 at
  P0 for the backup-safety defect itself, F12 at P2 for the undiscoverability) instead of letting
  one claim quietly override the other. Pass 1's grep-based evidence is the stronger, more
  falsifiable claim of the two and is presented as settled; Pass 2's "documented" wording is
  presented as-is without independent verification of that specific word.

- **Resolved, not conflicting (F16, symlink cwd divergence).** Pass 1 listed the
  physical-vs-logical cwd question in its own Unknown ledger, explicitly stating it could not test
  the harness. Pass 2 executed the test and found a real divergence. This is Pass 2 closing a gap
  Pass 1 named, not a disagreement — we note it because it's a clean example of the two-pass method
  working as intended.

- **Everywhere else the two passes overlap, they agree.** All eight true convergences (F01, F02,
  F07, F08, F10, F11, F13, F14) involve the same artefact and the same root cause, reached
  independently; neither pass's account of any of them contradicts the other's, they add different
  angles (e.g. F08: Pass 1 found the missing-pipe defect and the un-migrated duplicate parser that
  Pass 2 didn't test for; Pass 2 found the "offers to re-register" downstream effect Pass 1 didn't
  trace). An honest zero hard-conflicts is itself a real result: two independently-run, differently
  postured passes (analytical vs. adversarial) landing on the same root causes wherever they
  overlapped is a stronger signal than either pass alone.

## 5. Combined ledger

**Verified by execution (either pass).**
Block-merge truncation on a mangled end marker (F01, both passes). Registry trailing-slash and
missing-pipe defeats (F08, both passes on trailing-slash; Pass 1 alone on missing-pipe). Pre-commit
guard fires on `PEOPLE.md`, skips `README.md`, and blocks three benign sentences (F13, both passes
on the exemption; Pass 2 alone on the false positives). Absence of
`_meta/generative-orchestration-pass.md` (F29), absence of any `make-backup.sh` reference (F12),
absence of any LOG.md append-only check (F11) — all via repo-wide grep, Pass 1. `plutil -lint`
rejecting the live plists while `launchd` still tolerates them (F15, Pass 2). `bash -c` failing on a
space-containing `$HOME` (F09, Pass 2). `resolve-stream.sh` returning empty for a trailing-slash row
(F08, Pass 2). session-start/session-load divergence under a symlink (F16, Pass 2). `xargs` splitting
a spaced filename (F18, Pass 2). `update.sh`'s prefix-match dropping `runtime` entirely, and
`/bin/bash` 3.2 aborting on the resulting empty array under `set -u` (F07, Pass 2). Live
`git status --porcelain` on `~/permanence` showing 4 uncommitted stream files at time of review
(F03, Pass 2). `_meta/VERSION` present and matching tags after a `rm -rf .git && git init`
re-test — a hazard Pass 2 expected and disproved (adjacent to F19, not the same scenario: F19 is
about `VERSION` being *missing*, this test had it present).

**Verified by reading only (either pass).**
`nightly-consolidate.sh`'s `allowedTools` scope (F02). `install.sh`'s cogdebt scheduling (F10).
CI matrix coverage claims (F28). `update.sh`'s conflict/VERSION logic as traced code, not executed
against a live template (F07, F19).

**Combined Unknown — neither pass could check, or checked and stopped short.**
Whether Claude Code sets the hook process's cwd to the workspace in the way `session-start.sh`
assumes vs. the way `session-load.sh` assumes, beyond the symlink case Pass 2 did reproduce (F16;
the general mechanism, not the specific symlink instance). Whether an unrestricted `Write` in
`--allowedTools` is in fact unscoped in the installed Claude Code version — both passes read this
and neither executed a headless run to observe an actual out-of-scope write (F02). Runtime behaviour
of the cron and `schtasks` backends beyond what CI asserts (both passes). `perma-search.py`
retrieval quality against a real chromadb index — no venv built in either pass. Whether
`git fetch --tags` into a private notes repo can collide with a user's own tags in practice (Pass 1
only raised this; Pass 2 didn't address it). `make-backup.sh`'s `age`-encryption round-trip — no
`age` binary exercised (Pass 2). Whether a hook timeout could kill `events-listen.sh` *after* it
advances the cursor but before delivery — the ordering was read (cursor write precedes delivery in
both `events-listen.sh:31` and `stop-listen.sh:60`) but the race itself wasn't reproduced (Pass 2;
adjacent to F22, which is a different failure mode in the same files). Expired-token behaviour of
`claude -p` (Pass 2). All `example/` content (out of scope for both passes by instruction).

## 6. Apply order

1. **F01 — fix the block-merge in `install.sh` and `migrate-from-brain.sh`.** Verify the
   begin/end marker pair before touching the file; back up the target before any splice. Standalone
   fix, no dependencies. Do this first — it's the most likely to be hit by ordinary use (any edit
   history that leaves a mangled marker), and both passes independently rated it Andon.
2. **F03 — add a `git status --porcelain` pre-flight to `make-backup.sh`; stop pruning on a dirty
   or partial run.** Standalone fix. Do this alongside F01 — same tier of "ordinary use destroys
   data," and once fixed, wiring the script in per F12 becomes safe to do.
3. **F02 — scope `nightly-consolidate.sh`'s `Write` grant to `.consolidation/**`.** Standalone,
   one-line-shaped fix. Lower urgency than F01/F03 only because it requires an unusual trigger
   (injected content, model error, or a command-file edit) rather than firing under routine use —
   but it should land in the same pass since it's equally P0 and equally cheap to fix.
4. **F07 — rewrite `update.sh`'s conflict matching to be per-file, not prefix-based; guard the
   `APPLY_PATHS` expansion; don't bump `VERSION` on a skipped path.** Fixing this also closes the
   specific bash-3.2 crash and the false "up to date" state as side effects of the same change, and
   is a natural companion to F19 (missing-`VERSION` fallback) since both live in the same
   conflict/versioning code path in `update.sh` — worth doing as one pass over that file rather than
   two.
5. **F08 — normalize registry rows (trailing slash, pipe count) in `resolve-stream.sh`; delete the
   duplicate parser in `session-start.sh` and call the shared script; add the PY-4 validator.**
   Deleting the duplicate parser also prevents a recurrence of G-3's failure mode (a future fix to
   the shared resolver silently missing the SessionStart path) as a side effect.
6. **F04, F05, F09 — harden `install.sh` and `migrate-from-brain.sh`'s error handling and
   quoting.** `set -e -o pipefail` and a real pass/fail summary in `install.sh` (F04); a clean-tree
   check before `migrate-from-brain.sh`'s `rm -rf` block (F05); quote `"$PERMA"` in the generated
   scheduler command (F09). Bundle these three since they're all "install-family script continues
   silently past a failure" in the same file family, and F09's quoting fix is a natural add-on to
   the same pass touching `install.sh` for F04.
7. **F06 — age or alert on a stale `.perma-lock` in `nightly-consolidate.sh`.** Standalone.
8. **F13, F14, F15, F16, F17, F18 — the remaining P2 correctness bugs**, each independent
   (pre-commit header/exemption fix; portable `stat` replacement in `generate-contents.sh`; XML
   escaping in `schedule-task.sh`; shared cwd resolution between `session-start.sh`/`session-load.sh`
   — this pairs naturally with F08's resolver consolidation; a `python3`-absent fallback in
   `session-load.sh`; null-delimited `xargs` in `post-commit`). No sequencing dependencies between
   them; batch as convenient.
9. **F10, F11, F12, F19, F20 — the remaining documentation/consistency P2s.** F12 (wire up
   `make-backup.sh`) should land *after* F03, not before, so the script is safe by the time it's
   discoverable. The rest (cogdebt opt-in/placeholder fix, SPEC.md invariant language, stream
   discovery consolidation) are independent of each other and of everything above.
10. **F21–F29 — the P3s.** All independent, no fix ordering constraints; lowest priority, safe to
    batch into a documentation/cleanup pass whenever convenient.
