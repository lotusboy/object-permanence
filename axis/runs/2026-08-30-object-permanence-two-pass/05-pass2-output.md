# Pass 2 — Adversarial (Pre-mortem · Chaos · Poka-yoke)

Target: `runtime/*.sh`, `.githooks/*`, `runtime/commands/*.md`, `runtime/search/perma-search.py`, `SPEC.md`.
Method: read every script line by line, then **ran** the hostile cases below against real fixtures and against the live install on this machine. Pass 1 output not read.

---

## 1. BLUF

**Andon — two paths destroy or fail to protect user notes.** `runtime/make-backup.sh` backs up only *committed* history (`git bundle create --all`, line 39), then prints `OK … round-trip verified` (line 46) and **deletes older backups** (line 77). I checked the live install: `git -C ~/permanence status --porcelain` returns 4 modified files *right now*, including `LOG.md`, `PROJECT.md`, `QUESTIONS.md` and `_meta/REGISTRY.md`. A backup run this second would omit all of them, declare success, and prune. Three such runs and the newest notes are unrecoverable while the tool has said "verified" three times. Second: `runtime/nightly-consolidate.sh:71` grants an **unattended, headless Claude an unrestricted `Write` tool**, while `SPEC.md:24` claims "Generation passes are read-only by construction" and the script's own header (line 5) says "it writes only a report under `.consolidation/`". Nothing in code constrains the path — the safety property is a prompt, not a construction. Beyond those, `install.sh` can silently truncate `~/.claude/CLAUDE.md` (a file it does not own) and reports `done.` after any step has failed.

---

## 2. Pre-mortem findings

**PM-1 · P0 · Backup reports success while omitting the newest notes.**
`runtime/make-backup.sh:39` bundles committed history only. Nothing in the runtime auto-commits; `runtime/commands/perma-shutdown.md:18` makes committing a *model-followed instruction* at wind-down, and its own text concedes "an uncommitted write is the one state git cannot recover". Scenario: user skips `/perma-shutdown` for a week (or the session crashes at step 5), runs the documented backup, sees `OK … round-trip verified`, and line 77 prunes the bundle that *did* contain the last good copy. Laptop dies. A week of notes is gone, having been declared safe. A `git status --porcelain` check before bundling — refuse or warn loudly — costs one line.

**PM-2 · P0 · Unattended Claude with unrestricted write access to the whole filesystem.**
`runtime/nightly-consolidate.sh:69-75` runs `claude -p --permission-mode default --allowedTools "Read" "Glob" "Grep" "Write" …`. Every Bash grant on lines 72-74 is carefully path-scoped; `Write` is not scoped at all. Headless `default` mode auto-approves anything in the list with no human present. The only thing keeping this pass off the user's streams is the wording of `runtime/commands/perma-consolidate.md`. One prompt-injection-shaped note inside a stream (this tool reads untrusted meeting transcripts and Slack extracts by design), one model error, or one edit to that command file, and the nightly job overwrites `PROJECT.md` at 05:30 with nobody watching. `Write(…/.consolidation/**)` is supported and would make the SPEC claim true.

**PM-3 · P0 · `install.sh` can silently delete the rest of the user's global `CLAUDE.md`.**
`runtime/install.sh:42-45` replaces the delimited block with `awk`: on `perma:begin` it sets `skip=1`; only `<!-- perma:end -->` clears it. **Ran it:** given a file whose end marker has been removed (hand-editing, a merge, a truncated earlier write), everything after the begin marker is discarded. `settings.json` gets a `.perma-bak` (line 112); `CLAUDE.md` gets **no backup at all**, and `merge_agents_block` (line 59-72) has the identical defect against `~/.config/agents/AGENTS.md`, `~/.codex/AGENTS.md`, `~/.factory/AGENTS.md`. `runtime/migrate-from-brain.sh:86` repeats it for `brain:begin`. This breaks a tool other than Permanence, unrecoverably, on a re-run the user was told is idempotent.

**PM-4 · P1 · `install.sh` says `done.` when nothing was wired.**
`runtime/install.sh:7` sets `set -u` only — no `-e`, no `pipefail`. If `~/.claude/settings.json` is unparseable, the embedded Python prints a note and `sys.exit(0)` (line 94); the shell continues and line 152 prints `done.` The SessionStart *and* UserPromptSubmit hooks are then absent, so **Permanence loads no context in any session, forever**, and the user's evidence is a successful install. Same for a failed `cp`, a failed `launchctl`, a missing `python3`. The user concludes the product doesn't work and stops trusting it.

**PM-5 · P1 · `migrate-from-brain.sh` deletes machinery with no clean-tree check and no rollback.**
Lines 69-72 `rm -rf "${NEW:?}/${p:?}"` across `runtime .githooks templates SPEC.md README.md QUICKSTART.md CHANGELOG.md`, then `cp -R`. The comment (65-68) claims this is non-destructive because git history retains everything — **true only for committed content**. Uncommitted edits to `templates/` are gone with no prompt. `update.sh:34` requires a clean tree before applying; this far more destructive script does not. If `cp` fails at line 71 under `set -e`, the install is left with `runtime/` deleted and no machinery.

---

## 3. Chaos findings

| # | Sev | Condition | Line that breaks | What the user sees |
|---|---|---|---|---|
| **C-1** | P1 | `$HOME` contains a space (`/Users/Anna Smith`) | `install.sh:32-33` interpolates `$PERMA` unquoted into the scheduler's shell string | **Ran it:** `bash -c` reports `/Users/Anna: No such file or directory`. The nightly job fires every night and does nothing; the log redirect is also broken so nothing is written. Silent forever. |
| **C-2** | P2 | Any command containing `&` (i.e. the default `2>&1`) | `schedule-task.sh:134` embeds `$command` in `<string>` with no XML escaping | **Verified on the live install:** `plutil -lint` → *"unknown ampersand-escape sequence at line 5"* on both installed plists. `launchd` currently tolerates it (`launchctl print` shows the args intact) but the file is malformed XML — one stricter parser away from breaking. |
| **C-3** | P1 | A registry row path has a trailing slash | `resolve-stream.sh:20` / `session-start.sh:35`: `case "$TARGET" in ("$ws"\|"$ws"/*)` | **Ran it:** `/tmp/projA/` in the table → `resolve-stream` returns empty for `/tmp/projA`. The session is told "NOT registered", offers to register, and a duplicate row gets added. The user's notes are on disk and simply never load. |
| **C-4** | P2 | Workspace reached through a symlink | `session-start.sh:9` uses `pwd -P`; `session-load.sh:13-19` uses the hook JSON's logical `cwd` | **Ran it:** the same session gets contradictory instructions — session-start: "*this workspace is NOT registered*"; session-load: "*this workspace is the acme/linked stream, read it*". |
| **C-5** | P2 | `python3` absent | `session-load.sh:13-18` — `SID`/`CWD` come back empty | Falls to `nosid`, so the once-per-session marker (line 23) never applies: the auto-load paragraph is injected into **every prompt of every session**, permanently. |
| **C-6** | P2 | A note filename contains a space (`LOG 2026.md`) | `.githooks/post-commit:14-15` pipes into bare `xargs` | **Ran it:** the path splits into two arguments; `perma-search.py update` (line 200-207) finds neither, deletes nothing, re-adds nothing. Backgrounded to `/dev/null`, so `/perma-search` silently returns stale content with no error, indefinitely. |
| **C-7** | P2 | Running on Linux | `generate-contents.sh:27,41,47` use `stat -f` (BSD syntax; on GNU coreutils `-f` means *filesystem*) | Every date column empty and the newest-first sort key blank — `CONTENTS.md` becomes an unordered undated list. `schedule-task.sh` ships a Linux backend, so Linux is a supported target. |
| **C-8** | P2 | User edits one file under `runtime/` — which `install.sh:34` explicitly instructs them to do | `update.sh:102` `case "$c" in "$p"*)` prefix-matches the whole directory | **Ran it:** one conflict (`runtime/cogdebt-scan.sh`) drops `runtime` entirely, so all 20 scripts stop updating. The warning names only the one file. If every path conflicts, `APPLY_PATHS` is empty and on macOS's stock **bash 3.2** (`/bin/bash --version` → 3.2.57) `"${APPLY_PATHS[@]}"` under `set -u` aborts the script mid-apply — verified. |
| **C-9** | P3 | Fresh install, untouched watch-list | `cogdebt-scan.sh:39` defaults to the literal placeholder `$HOME/path/to/your/ai-built-repo` | The weekly launchd job runs forever writing `not a git repo` reports and never emits an event. Separately, `cogdebt-scan.sh:81` uses an **unquoted heredoc** with `cur=json.loads('''$ALL''')` at line 85; the un-escaped error branch at line 48 interpolates `$R` raw, so a repo path containing `'''` injects Python into a scheduled job. |

---

## 4. Poka-yoke findings

**PY-1 · P1 · A stale `.perma-lock` silently and permanently kills the nightly job.**
`nightly-consolidate.sh:56`: `[ -f "$PERMA/.perma-lock" ] && exit 0` — no age check, no `alert()`, exit 0. The lock is created and released purely by a model following `perma-consolidate-review.md:96` and `:109`; a Ctrl-C, crash, or context exhaustion between those steps leaves it. `session-start.sh:20` at least warns after 240 minutes; the nightly has no such guard, so a lock from March quietly disables consolidation for the rest of the year. This directly contradicts the same script's stated principle 15 lines below (`:78-92`: *"Silent-green is worse than a loud failure"*). Fix: age the lock out or `alert()` on skip.

**PY-2 · P2 · The "lock-fenced, worktree-isolated" guarantee is prose, not code.**
`SPEC.md:24` states state-changing maintenance lands under a "single revertable `--no-ff` envelope, lock-fenced, worktree-isolated". Every one of those mechanisms lives in `runtime/commands/perma-consolidate-review.md` as instructions to a language model. No script takes the lock, no script checks it before writing, nothing enforces the worktree. Two concurrent sessions in `~/permanence` are unfenced.

**PY-3 · P2 · The people-guard fails open silently and fires on ordinary engineering prose.**
`.githooks/pre-commit:51-56`: only `+++ b/`-prefixed headers set `file`; a git-quoted path (`+++ "b/…"`, emitted for non-ASCII names) falls to the `+++ *` branch, `file=""`, and **every added line in that file is skipped with no notice**. Line 61 exempts *any* `README.md`, including a stream's own. In the other direction, **ran** three benign sentences through the patterns: `"the vendor API docs are dishonest about rate limits"`, `"idempotent by nature"`, `"the retry logic was incompetent"` — all three block the commit (`:43`, `:40`). A guard that both misses breaches and blocks normal notes trains the user into habitual `--no-verify`.

**PY-4 · P2 · No validator for the one hand-edited machine-read file.**
`_meta/REGISTRY.md` is parsed by three scripts with no schema check. C-3 shows a single trailing `/` disconnects a project from its memory, presenting as "you have no notes". A `perma-registry-check` that flags trailing slashes, non-absolute paths, unresolvable directories and duplicate rows removes the entire class.

**PY-5 · P3 · Destructive scripts lack the dry-run their sibling has.**
`update.sh` defaults to dry-run (`:29`). `migrate-from-brain.sh` (`rm -rf` × 7 paths) and `install.sh` (writes four files it does not own) have neither a dry-run nor a diff preview, and neither backs up `CLAUDE.md`/`AGENTS.md` the way `install.sh:112` backs up `settings.json`.

---

## 5. Verified / Unknown ledger

**Verified — actually executed on this machine:**
`plutil -lint` rejecting both live plists and `launchctl print` showing launchd tolerating them (C-2) · `bash -c` on the space-containing command failing (C-1) · the `awk` block-replace deleting file remainder with a missing end marker (PM-3) · `resolve-stream.sh` returning empty for a trailing-slash row and correct for a space-containing path (C-3) · session-start/session-load divergence under a symlink (C-4) · `xargs` splitting a spaced filename (C-6) · all three pre-commit false positives (PY-3) · `update.sh`'s prefix-match dropping `runtime` (C-8) · `/bin/bash` 3.2 aborting on an empty array under `set -u` (C-8) · `git -C ~/permanence status --porcelain` showing 4 uncommitted stream files right now (PM-1) · `_meta/VERSION` = `v1.0.2` and three matching tags, so `update.sh`'s conflict detection *does* resolve after a `rm -rf .git && git init` re-init (a hazard I expected and disproved).

**Read but not run:**
`--allowedTools "Write"` being unrestricted (PM-2) — I read the grant and the contradicting SPEC/header claims; I did not execute a headless run to observe an out-of-scope write.

**Unknown — could not test:**
Claude Code hook internals: whether a 10 s timeout kills `events-listen.sh` *after* it advances the cursor at line 31 (the cursor is written **before** delivery in both `events-listen.sh:31` and `stop-listen.sh:60`, so a kill in that window loses the message permanently — ordering read, race not reproduced) · the cron and `schtasks` backends (`schedule-task.sh:157-176`; the file's own header admits they are untested) · `make-backup.sh`'s `age` round-trip (no `age` binary exercised) · `perma-search.py` against a real chromadb index (no venv present) · expired-token behaviour of `claude -p`.

---

## 6. Verdict

**No — not today.** I would not let a non-technical friend run `install.sh`, because it edits four files it does not own with a truncation bug and no backup (PM-3), reports `done.` when it has wired nothing (PM-4), and the one command that is supposed to make their notes recoverable tells them it verified a backup that omits everything they have not committed (PM-1). Fix PM-1, PM-2 and PM-3 and this becomes a yes with caveats — the design instincts here (the artefact assert at `nightly-consolidate.sh:78-92`, the cross-install ownership guard at `schedule-task.sh:100-118`, the atomic `.tmp`-then-`mv` in `make-backup.sh:42`) are better than most; the gap is that several of the strongest safety *claims* are enforced by prose rather than by code.
