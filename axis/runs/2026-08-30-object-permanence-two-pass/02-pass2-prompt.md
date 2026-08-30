# Pass 2 — Adversarial

You are running **Pass 2 (adversarial)** of a Two-Pass Axis Engineering review. Fresh context,
no prior knowledge of this project.

**Do NOT read `04-pass1-output.md`.** Another agent reviewed this same target analytically. Its
output exists in the same folder. Reading it would anchor you on its framing and destroy the
independence that makes this protocol work. If you find yourself curious what it said, that is
exactly the impulse to refuse. Approach the code fresh.

## Repository

`/Users/lotusboy/workspaces/object-permanence`

All paths relative to that root.

## What this project is

Permanence gives an AI coding assistant persistent memory of a project across sessions. A
user's notes live as plain markdown in `~/permanence`, organised into "streams" — one folder
per project, holding `PROJECT.md`, `LOG.md`, `PEOPLE.md`, `QUESTIONS.md`. Shell scripts in
`runtime/` wire this into Claude Code through hooks, slash commands and a scheduled nightly
job that runs Claude unattended. The repo is cloned to `~/permanence` and re-initialised as
the user's own git repo, so machinery and notes share one directory and one history.

Two facts that shape the risk surface, both worth verifying yourself rather than taking from
me: `install.sh` writes into files it does not own (`~/.claude/settings.json`,
`~/.claude/CLAUDE.md`, global `AGENTS.md` locations, the OS scheduler), and the notes it
manages are, for its users, irreplaceable.

## Your target

`runtime/*.sh` (primary), `.githooks/pre-commit` and `post-commit`, `runtime/commands/*.md`,
`runtime/search/perma-search.py`, and `SPEC.md` where it claims a safety property.
**Do not review `example/`.**

## Your three lenses

**1. Pre-mortem.** It is a year from now and Permanence has failed a user badly enough that
they tell other people not to use it. Work backwards: what happened? Write the most plausible
failure stories, each traced to the specific lines that permit them. Rank by how bad the
outcome is for the user, not by how likely you think it is. Losing notes, corrupting a git
history, and silently breaking someone's Claude Code setup are all end-states worth reasoning
back from.

**2. Chaos Engineering.** Assume the environment is hostile and ask what the code does. Work
through concrete conditions rather than generalities: `python3` absent; no network; the disk
full; a write interrupted halfway; two Claude sessions running the same command at once; the
nightly job firing while a user is mid-edit; a registry file with a path containing spaces, a
pipe character, a symlink, or a trailing slash; a stream name that is also a shell
metacharacter; `$HOME` unset or pointing somewhere unexpected; a git repo in a detached HEAD
or mid-rebase; a scheduled job whose token has expired. For each, name the line that breaks
and what the user sees.

**3. Poka-yoke.** Where is a mistake *possible* that a guard could make impossible? Look for
destructive operations without a confirmation or a dry-run; irreversible writes with no
backup; paths where being in the wrong directory does damage; places where the failure is
silent rather than loud. Pay attention to anything that exits 0 while having done nothing,
since a green exit that means "nothing ran" is worse than a red one.

## Ledger

Maintain a **Verified / Unknown** ledger. Behaviour you could not actually test — a scheduler
backend for an OS you are not running, Claude Code hook internals, a network call you did not
make — goes in Unknown. State clearly what you *read* versus what you *ran*.

## Report back

Write your findings to:

`axis/runs/2026-08-30-object-permanence-two-pass/05-pass2-output.md`

Structure, in this order:

1. **BLUF** — one paragraph, leading with the worst thing you found.
2. **Pre-mortem findings** — failure stories, worst outcome first
3. **Chaos findings** — condition → line that breaks → what the user sees
4. **Poka-yoke findings** — the missing guards
5. **Verified / Unknown ledger**
6. **One-sentence verdict** on whether you would let a non-technical friend install this today.

Number every finding (`PM-1`, `C-1`, `PY-1`) and label each with a severity you assign
yourself: **P0** (Andon — data loss or breaking another tool), **P1**, **P2**, **P3**. Every
finding needs a `file:line` citation and a concrete failure scenario — specific inputs or
conditions leading to a specific bad outcome, not "this could be a problem".

Around 1,200 words. Do not pad. A small codebase honestly reviewed yields fewer findings than
a large one, and manufacturing severity to look thorough is an explicit anti-pattern of this
methodology.

**Andon:** the moment you find a path that destroys user notes or git history, or that can
break a tool other than Permanence, stop and headline it at the top of your BLUF.

**Anti-anchoring requirement:** you are the fresh-eyes pass. Where the code's own comments
explain why something is safe, verify the claim against the code rather than accepting it.
Several comments in this repo assert safety properties; at least check whether they are true.
