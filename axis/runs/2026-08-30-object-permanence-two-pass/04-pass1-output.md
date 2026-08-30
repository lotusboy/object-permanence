# Pass 1 — Analytical (First Principles · MECE · Genba)

Target: `/Users/lotusboy/workspaces/object-permanence` @ `680e3d5`. `example/` excluded.

## 1. BLUF

**Andon first.** `runtime/install.sh` merges a delimited block into five files it does not own
(`~/.claude/CLAUDE.md` and four global `AGENTS.md` paths) with an `awk` filter that starts skipping
at `<!-- perma:begin` and stops only at a byte-exact `<!-- perma:end -->`. If that end marker is
absent or altered by one character, **everything after the begin marker is deleted**. I reproduced
this: a file with `<!-- perma:end-->` (one space short) went from 6 lines to 3, losing the user's own
global instructions. Unlike the `settings.json` path (`install.sh:112`), no backup is taken. The same
code runs against Codex's, droid's and Amp's config files (`install.sh:63-76`), and `update.sh:110`
re-runs the whole installer on every upgrade.

Otherwise: this is a small, carefully-built, unusually well-commented system whose **machinery is
sound and whose guarantees are overstated in specific, locatable places**. The core loop is two hooks
that emit *instructions*; nothing in the repo reads or writes a stream. `README.md:67` says so
honestly; `SPEC.md:24` ("read-only by construction") and `perma-consolidate.md:12` ("changes nothing
on disk") do not. The decomposition has real overlaps (five context-load paths, three stream-discovery
rules) and one orphan (`make-backup.sh`, the only implementation of invariant 7, referenced by
nothing).

## 2. First Principles findings

**FP-1 — The system's actual mechanism is instruction emission, and two documents claim more.**
Every runtime script that touches a stream only *prints text* (`session-start.sh:62-64`,
`session-load.sh:33`). No component reads or writes `PROJECT.md`. That is a legitimate design, and
`README.md:67` states it plainly. But `SPEC.md:24` asserts "Generation passes are read-only by
construction" while the unattended nightly grants the model an **unrestricted `Write` tool**
(`nightly-consolidate.sh:71`) with no path scoping — the comment at `nightly-consolidate.sh:4-6`
claims "read access + report-write … and nothing else". *Consequence:* the headless 05:30 run can
write any file on disk; the only thing stopping it is prose in `perma-consolidate.md:82`.

**FP-2 — Seven of eight invariants have no code behind them.** `SPEC.md:20-27` states 8 invariants.
Only #3 (people-rule) is mechanised, by a lexical heuristic over staged `*.md`
(`.githooks/pre-commit:26-76`). #2 (append-only LOG) has no check anywhere — `grep` over `runtime/*.sh`
and `.githooks/*` finds no LOG.md logic at all. #5 (human ratification, "lock-fenced,
worktree-isolated, `--no-ff`") exists only as instructions in `perma-consolidate-review.md:96-109`;
the sole code is a *warning* (`session-start.sh:15-25`) and a skip (`nightly-consolidate.sh:56`).
*Consequence:* the invariants are conventions, not properties; a model that deviates leaves no trace.

**FP-3 — `cogdebt-scan.sh` does not earn its always-on slot.** It ships with a placeholder watch-list
(`cogdebt-scan.sh:39`: `$HOME/path/to/your/ai-built-repo`), measures only Python (`:50` `ls-files
'*.py'`), and `install.sh:33` schedules it weekly on **every** install regardless. `install.sh:34`
admits the list needs editing first. *Consequence:* a default install runs a weekly job that either
reports `not a git repo` forever, or — pointed at a non-Python repo — reports `src_loc: 0`, which
trips both floors (`:109`, `:111`) and emits false breach events into every open session (`:123-128`).

**FP-4 — The only implementation of invariant 7 is unreachable.** `runtime/make-backup.sh` (age-encrypted
bundle + round-trip verify) is referenced by **nothing** — not `install.sh`, `README.md`,
`QUICKSTART.md`, `SPEC.md`, `perma-help.sh`, or any command (verified by repo-wide grep).
*Consequence:* a user following the documented path never learns it exists, so `SPEC.md:26`'s custody
invariant is unimplemented in practice. Note also `make-backup.sh:39` bundles committed history only,
so uncommitted stream edits — which `perma-shutdown.md:16` calls "the one state git cannot recover" —
are absent from the backup.

## 3. MECE findings

**M-1 — The context-load paths overlap; they do not partition.** `install.sh` wires the SessionStart
hook (`:100-103`), the UserPromptSubmit `session-load` hook (`:107-110`), writes the CLAUDE.md block
(`:37-50`), and writes `~/.config/agents/AGENTS.md` **unconditionally** (`:73`). The CLAUDE.md block
describes itself as "fallback for environments without SessionStart hooks"
(`claude-md-block.md:2`) — but it is installed into `~/.claude/CLAUDE.md`, which Claude Code always
reads, i.e. exactly where the hook already fires. *Consequence:* in Tier-1 Claude Code at least three
paths instruct the same load, one of them telling the model to shell out to `session-start.sh` a
second time.

**M-2 — Stream discovery is implemented three times with three different rules.** `SPEC.md:12` says a
stream exists *iff* it has a `PROJECT.md`. `generate-contents.sh:55` searches unbounded;
`perma-help.sh:164` uses `-mindepth 2 -maxdepth 3`; `perma-brief.md:9` hard-codes
`<customer>/<project>`. Meanwhile `perma-register.md:19` explicitly permits a bare `<slug>` stream.
*Consequence:* a stream nested three deep is indexed but invisible to the morning brief and to the
help counter.

**M-3 — `REGISTRY` and `GROUPS` answer genuinely different questions, but resolution is duplicated.**
The questions differ as documented (`GROUPS.md:6-9`) — which stream loads vs which programme it
reports into. The *lookup*, however, is code for streams (`resolve-stream.sh`) and prose for groups
(`perma-shutdown.md:15`: "longest-prefix match on cwd, same as the registry"), plus a third ad-hoc
parser in Python (`perma-help.sh:128-145`). There is no `resolve-group.sh`. *Consequence:* the group
lookup's correctness depends on a model re-deriving prefix matching by hand each time.

**M-4 — The opt-in/always-on split is incoherent for the cognitive-debt scan.** `README.md:71,76,78`
lists it under "Optional extras (opt-in)" and "deliberately off by default"; `install.sh:33` schedules
it always; `SPEC.md:42` lists it as part of the fully-automated Tier-1 binding. Three documents, three
answers. Events and search *are* genuinely opt-in (`install.sh:137-145`), so the category itself is
sound — the scan is misfiled.

**M-5 — `SPEC.md` is behind the implementation in two places.** Its six triggers (`§3:33-38`) and the
binding paragraph (`:42`) never mention `session-load.sh`/UserPromptSubmit — the path `README.md:64`
calls "the *reliable* trigger" — nor the events bus nor search. `SPEC.md:42` also still says "add the
two settings.json entries it reports", which `install.sh:97-114` now merges automatically.
*Consequence:* the harness-independent contract, which is the rebuild instruction for another agent,
omits the load-bearing read path.

**M-6 — Canonical files are not fully covered.** `SPEC.md:11` names six canonical stream files;
`templates/` ships four (no `STRATEGY.md`, no stream `README.md`), while `README.md:88` calls
`templates/` "blank skeletons for the canonical files". `session-start.sh:63` also never asks for the
stream's `README.md`, which `SPEC.md:11` designates as orientation.

**M-7 — Install has no inverse.** Five machine-wide writes (commands dir, `settings.json`, CLAUDE.md,
AGENTS.md paths, two scheduled jobs) have no uninstall path; only `shutdown-nudge.sh:40` offers one.

## 4. Genba findings

**G-1 — Block-merge truncation (the Andon item).** `install.sh:42-45` and `:63-67`. Reproduced in a
scratch dir: mangled end marker ⇒ file reduced to the block alone. No backup on this path.

**G-2 — Two registry inputs silently defeat the parser.** Ran `resolve-stream.sh` against a synthetic
registry: a row whose path carries a **trailing slash** (`/Users/me/work/proj-two/`) matches nothing —
neither the directory nor its children — because `resolve-stream.sh:20` tests `"$ws"|"$ws"/*`. A
hand-added row **missing its leading `|`** is silently dropped, because `IFS='|' read -r _ ws stream`
(`:15`) consumes the path as the discarded first field. Both look correct to a human.
*Consequence:* silent unregistration, presenting as "Permanence just doesn't load here".

**G-3 — The comment says factored out; the code says duplicated.** `resolve-stream.sh:3` claims it was
"factored out of `session-start.sh`", but `session-start.sh:30-39` still carries a verbatim second
copy of the parser and never calls the script. Every other consumer does (`session-load.sh:28`,
`events-listen.sh:20`, `stop-listen.sh:31`, `emit-event.sh:19`). *Consequence:* a fix to G-2 applied
in one place silently misses the SessionStart path.

**G-4 — No existence check on the resolved stream.** `session-start.sh:61-64` builds `STREAM_DIR` and
instructs the read without testing the directory exists. A renamed or deleted stream yields a
confident "read these files now" for files that aren't there.

**G-5 — `update.sh` bumps `VERSION` even when it skipped work, then declares itself current.**
Conflict skipping is by path *prefix* (`:99-105`): one customized file under `runtime/` excludes the
entire `runtime` directory from the checkout. `VERSION` is then written unconditionally (`:112`) to
the new tag. On the next run, `:53-55` sees `CURRENT = LATEST_TAG` and prints "Already up to date",
exiting before the diff. *Consequence:* skipped machinery never lands and is never listed again.

**G-6 — The "never silently overwritten" promise has a hole.** Conflict detection runs only if
`$CURRENT` resolves as a ref (`:69`). If `_meta/VERSION` is missing, `CURRENT="unknown"`, the branch is
skipped, `:77` suppresses even the warning, `CONFLICTS` stays empty, and `:107` checks out **every**
machinery path — `README.md`, `SPEC.md`, all of `runtime/` — over the user's customizations. That
contradicts `SPEC.md:38` ("negotiated per file, never silently overwritten"). Recoverable via git, but
unannounced.

**G-7 — `generate-contents.sh` is macOS-only.** `stat -f '%m'` / `stat -f '%Sm'` at `:27`, `:41`, `:47`
is BSD syntax; on GNU `stat`, `-f` means *filesystem status* and yields nothing. `post-commit:5`
swallows the failure (`2>/dev/null || true`). *Consequence:* on Linux/WSL the inventory renders with
blank dates in arbitrary order, silently, against `QUICKSTART.md:32`'s "Works on macOS and Linux with
no changes".

**G-8 — A stale self-assessment.** `schedule-task.sh:8-10` says the Linux and Windows backends "could
not be run-tested"; `ci.yml:100-159` runs `install.sh` on ubuntu/macos/windows and asserts the real
cron/launchd/schtasks entry exists and unschedules cleanly. The comment understates the evidence.

**G-9 — The people-guard exempts a canonical file.** `.githooks/pre-commit:61` skips
`README.md|*/README.md`. Verified: identical breaching text in `stream/PEOPLE.md` was flagged and in
`stream/README.md` was not — yet `SPEC.md:11` lists `README.md` as a canonical per-stream file.

**G-10 — Three references to a file that does not ship.** `_meta/generative-orchestration-pass.md`
is cited by `SPEC.md:37`, `SPEC.md:40` and `.githooks/post-commit:20` as the rationale for a
deliberately-unbuilt feature; it is absent from the repo. CI's link check (`ci.yml:23-38`) cannot
catch it because it is a bare path, not a Markdown link.

**G-11 — Event delivery is keyed to the stream, not the session.** `events-listen.sh:24-31` and
`stop-listen.sh:36-40` share one cursor file per stream and advance it to the line count on every run.
Two sessions open on the same workspace: the first to fire consumes the event; the second never sees
it. The docs' "delivered exactly once" (`install.sh:136`) holds across the two *hooks*, not across
concurrent sessions.

## 5. Verified / Unknown ledger

**Verified by execution.** Block-merge truncation (reproduced). Registry trailing-slash and
missing-pipe defeats (ran `resolve-stream.sh` on a synthetic registry). Pre-commit guard fires on
`PEOPLE.md` and skips `README.md` (ran the hook in a scratch repo). Absence of
`_meta/generative-orchestration-pass.md`, absence of any `make-backup.sh` reference, absence of any
LOG.md append-only check (repo-wide grep).

**Verified by reading only.** `update.sh` conflict/VERSION logic (G-5, G-6) — traced, not executed
against a live template. `nightly-consolidate.sh` allowedTools scope (FP-1). `install.sh` scheduling
of cogdebt (FP-3). CI matrix coverage (G-8).

**Unknown — not asserted either way.** Whether Claude Code sets the hook process's cwd to the
workspace (`session-start.sh:9` relies on `pwd -P`; `session-load.sh:13-19` reads `cwd` from the hook
JSON, which is stronger — the difference matters but I cannot test the harness). Whether an
unrestricted `Write` in `--allowedTools` is in fact unscoped in the installed Claude Code version.
Runtime behaviour of the cron and `schtasks` backends beyond what CI asserts. `perma-search.py`
retrieval quality (venv not built). Whether `git fetch --tags` into a private notes repo can collide
with a user's own tags in practice. All `example/` content (out of scope by instruction).

## 6. Verdict

The shape mostly matches the purpose — a small instruction-emitting layer over plain markdown is the
right build for externalised memory — but the documentation claims mechanical guarantees at four
points where the code provides only instruction-following, and the one installer that writes to files
it does not own can destroy their contents without a backup.

**Findings: 22** (FP 4 · M 7 · G 11).
