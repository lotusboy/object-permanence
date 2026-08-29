---
description: Interactive walkthrough of a Permanence consolidation report — decide each item one at a time (yes / no / with-notes), see a final summary to catch mistakes + dependencies, then apply the accepted ones on `main` via a single audit branch.
---

# Permanence — Consolidation Review

Walk the owner through a consolidation report from `/perma-consolidate`, one item at a
time, like a permission prompt: a clear choice with room for nuance. Capture every
decision, show a single final summary so he can catch his own mistakes and any
dependencies between items, then — and only then — apply the accepted ones.

The generator changed nothing; **this is the only step that touches Permanence.**
Apply happens on a short-lived audit branch **in an isolated worktree** that is
`--no-ff` merged into `main`, so the whole consolidation lands as one revertable,
named unit in git history — and concurrent live sessions on `main` never find
themselves silently sitting on the audit branch (the recorded multi-writer failure).
A `.perma-lock` file fences the apply window; every session's start-hook warns
writers off while it is held.

## Phase -1 — Lock hygiene

Before anything: if `~/permanence/.perma-lock` exists, read it (line 1 = epoch seconds,
line 2 = owner note). Under 4 hours old → another review is genuinely in flight;
say so and stop. Over 4 hours old → it is stale (a crashed or abandoned review);
tell the owner, remove it with his go-ahead, and continue.

## Phase 0 — Find the report

1. List candidates newest-first: `ls -t ~/permanence/.consolidation/REPORT-*.md 2>/dev/null`.
2. **Default to the newest.** If the owner named a specific run, use that. If several un-reviewed reports exist, the newest was generated against the latest Permanence state and **supersedes the older ones** — say so, and note that the older ones will be archived automatically at close-out (Phase 5), so there's nothing to decide here. Don't offer to delete them: the sweep handles it, and the reports are the audit trail of how decisions were made.
3. If there's no report, say so and suggest `/perma-consolidate` first. Stop.

## Phase 1 — Orient

Read the chosen report in full. One-line orientation before diving in: the run
timestamp and the counts — e.g. *"Run 2026-06-05-1126: 2 mechanical edits, 5
verdicts, 4 supersessions, 3 moves. Nothing applied yet — walking through now."*

Offer a shortcut up front: **"Apply all the mechanical edits as a block and walk
through only the judgement calls?"** (the mechanical ones are safe, recommended,
and usually trivial yeses) — or review every item including mechanical. Let the owner pick.

## Phase 2 — Discuss, one point at a time

This is a **discussion, not a menu.** the owner's working memory is limited — it's why
Permanence exists and why he talks things through. Do **not** hand him a decoded list
of options to read and choose from; that overloads him. The map and the option-decode
are *your* working tools, not his reading. The loop per point:

1. **You hold the picture; you ask the question.** Use the forks (below) to work out the *single fact you actually need* from him for this point, and ask it as one plain, open question — with the minimum context to make it answerable. Auto-expand any referenced Q-number / prior decision / stream so he isn't recalling it cold.
2. **Let him perma-dump.** He answers freely, in his own words, usually with more than you asked for.
3. **You map the dump to the action** — Confirm / Revise / Wrong / Prune, which version wins, do / skip. He does *not* pick from the decode. Give a one-line read-back of what you took ("got it — that read closed positive, and Q37's now on us"), then move on.
4. **Record, don't apply.** Collect decisions; edit nothing yet.

Keep each point light: one question → his dump → a one-line read-back → next.
**Cluster** points that share a pivot fact into a single question (e.g. three reads
on the same person that all turn on one thing he knows), so he answers the upstream
fact once and you fan it out across the dependent points.

The single confirmation happens **once, at the end** (Phase 3) — the only place he
eyeballs everything together. Don't ask him to confirm per item.

**Your internal decode** (for mapping his words to an edit — *not* for him to read):
- **Confirm** — read held; leave it, add a dated `[Confirmed YYYY-MM-DD]` tag.
- **Revise** — picture moved; rewrite to his wording, dated.
- **Wrong** — mistaken and worth recording so; mark corrected with date + correction (a trail, not a silent delete).
- **Prune** — moot/overtaken; delete the line (the one sanctioned deletion). *Wrong vs Prune:* Wrong keeps a trail because it mattered; Prune just clears noise.

**Building the question (the picture is yours to hold).** Trace the forks around each
point — the upstream ones that led here and the downstream ones it feeds, even far
ones — to find the *right single question*. The far forks tell you which fact unlocks
the most. Surface only as much of the map as the question needs; keep the rest.

**AskUserQuestion is the exception, not the default.** Use it only when a point
genuinely reduces to a crisp either/or and a tap is easier than typing — and even
then keep options to a few short words. Default to open conversation.

(Durable guidance — if this way of deciding helps the owner, capture it as a memory.)

## Phase 3 — Final summary (the catch-mistakes gate)

Before touching anything, print one compact summary of **every** decision, grouped
by kind. Then actively help the owner catch problems — the step he asked for:

- **Drift check.** Re-open each file a *mechanical* (or otherwise verbatim) edit targets and confirm the quoted `old` text still matches the file as it is now. If a file changed since the report was generated, flag it and re-derive the edit against current content rather than applying stale text. (This is why apply is fresh, not a stale-branch merge.)
- **Consistency checks.** Flag decisions that fight each other — e.g. "you confirmed the inference that X but pruned the note Y it depends on"; "you chose to Apply Mechanical 2 *and* Revise the same lines in Verdict 4 — they collide."
- **Dependencies / knock-ons.** Surface what one decision implies for another — e.g. "choosing *9-week wins* on Supersession 2 means Q24 should close and the Headline's August dates go — shall that follow automatically?"; "this verdict touches both PEOPLE.md and PROJECT.md — two edits."
- **Order of operations.** Note where one edit must precede another.

End with a single go-ahead: **Apply all as summarised** / **Let me adjust** (loop back to specific items) / **Cancel** (apply nothing). Loop until he's satisfied.

## Phase 4 — Apply (lock → worktree → merge; the lock spans the whole window)

If nothing was accepted, skip to Phase 5.

1. **Take the lock** the moment the owner says go: `printf '%s\nconsolidate-review %s\n' "$(date +%s)" "$RUN" > ~/permanence/.perma-lock`. It is released in step 6 — *whatever happens in between*. From here until release, live sessions are warned off by their start-hook.
2. **Create the audit branch in an isolated worktree** — never `checkout -b` in the shared tree: `RUN=<run-id>; git -C ~/permanence worktree add "/tmp/perma-consolidate-$RUN" -b "consolidate-applied/$RUN" main`. All edits happen under `/tmp/perma-consolidate-$RUN/`; the shared tree at `~/permanence` stays on `main` and untouched throughout.
3. **Make each accepted edit in the worktree**, **one commit per logical change**, descriptive message (e.g. `consolidate: close Q24 + drop stale August dates (9-week framing won)`). Apply by kind:
   - **Mechanical / Apply** → the exact edit from the report (re-derived if drift was found).
   - **Confirm** → annotate the inference as confirmed with today's date (close the loop, don't delete).
   - **Revise / Wrong** → rewrite to the owner's wording (gentle register); keep the fact, fix the read.
   - **Prune** → remove the stale inference (the one sanctioned deletion).
   - **Supersession** → update the winning version; mark/close the loser (close the question, remove the superseded block — supersession, not silent deletion).
   - **Move** → relocate / fold-up / complete-the-entity as decided.
4. **Merge-time preconditions** (the race re-checks — `main` may have moved while you worked):
   - **Clean shared tree required.** `git -C ~/permanence status --porcelain` must be empty. If it isn't, tell the owner what's uncommitted and wait — never stash or commit someone else's work-in-progress to force the merge.
   - **Re-run the drift check at merge time:** if `main` gained commits since Phase 3's check, re-verify each applied edit's `old` text against current `main`. Any edit whose target moved gets re-derived in the worktree (or dropped with a note) before merging.
5. **Merge as one unit on the shared tree** (which is already on `main`): `git -C ~/permanence merge --no-ff "consolidate-applied/$RUN" -m "Consolidation $RUN: <one-line tally>"`. The `--no-ff` merge commit is the audit anchor — the whole pass reverts with one `git revert -m 1`. **If the merge conflicts: abort the whole envelope** (`git merge --abort`), keep the branch for forensics, tell the owner the report needs regenerating against current state — never resolve consolidation conflicts ad hoc.
6. **Always clean up, on every path** (success, conflict-abort, or cancel): remove the worktree (`git -C ~/permanence worktree remove "/tmp/perma-consolidate-$RUN" --force` if needed), delete the branch on success (`git branch -d`), and **release the lock** (`rm ~/permanence/.perma-lock`). The lock must never outlive the session.
7. Honour every convention exactly as `/perma-consolidate` describes — append-only LOG, supersession-not-deletion, the people-rule (fact/inference split, behaviour-not-identity), **voice** (gentle register), one-way flow. The pre-commit guard runs on each commit; if it flags, reframe rather than `--no-verify` (unless a confirmed false positive / intended quote).

## Phase 5 — Close out

1. **Record it as a perma-meta event.** Append a short entry to `~/permanence/LOG.md` (root): date, run id, one-line tally — *"Consolidation (run 2026-06-05-1126): applied 2 mechanical edits; closed Q24; pruned 1 stale inference; relabelled Dan-meeting questions. Merge a1b2c3d."* This keeps the maintenance pass itself in Permanence's history. (Commit this on the working branch — it's outside the merge envelope, which is fine.)
2. **Archive the report — and sweep every superseded one with it.** The consolidate pass is **idempotent**: each run re-scans the whole Permanence from scratch, so anything still true reappears in the next report and anything fixed disappears. An un-reviewed report older than the one just reviewed therefore carries **no information the newer one lacks** — leaving them at the top level makes an unreviewed backlog that looks like work but isn't.

   ```bash
   mkdir -p ~/permanence/.consolidation/done
   mv ~/permanence/.consolidation/REPORT-<run-id>.md ~/permanence/.consolidation/done/
   # sweep everything older than the run just reviewed (idempotent pass ⇒ superseded)
   # NOTE: [[ ]] not [ ], and no backslash on the <. `[ "$a" \< "$b" ]` is valid POSIX sh
   # but zsh rejects it outright ("condition expected: <"), so on a default macOS shell the
   # sweep errors out and silently moves nothing — leaving the backlog it exists to clear.
   for f in ~/permanence/.consolidation/REPORT-*.md; do
     [ -e "$f" ] || continue
     [[ "$(basename "$f")" < "REPORT-<run-id>.md" ]] && mv "$f" ~/permanence/.consolidation/done/
   done
   ```

   **Then verify, don't assume:** `ls ~/permanence/.consolidation/REPORT-*.md` should report no matches.
   If any remain that are older than the reviewed run, the sweep failed — move them by hand and say so.

   Archive, never delete — the decisions live in git history, but the reports are the audit trail of *how* they were made. **Leave any report NEWER than the reviewed run in place** (it was generated against a later state and has not been reviewed). Tell the owner how many were swept, so a large number registers as "the nightly was running and nobody was reading it" rather than passing silently.
3. **Verify the lock and worktree are gone** (`ls ~/permanence/.perma-lock` fails; `git -C ~/permanence worktree list` shows only the main tree) — state it in the close.
4. Give the owner a tight close: what landed (with the merge commit hash), what he chose to **skip** (so it's not forgotten — it'll resurface next run if still true), and anything still genuinely open.

## If invoked with nothing to review

If there's no report, or the newest report's sections are all empty, say so plainly
and offer to run `/perma-consolidate` to generate a fresh one.
