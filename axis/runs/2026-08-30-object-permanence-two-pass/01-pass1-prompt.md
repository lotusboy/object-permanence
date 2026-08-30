# Pass 1 — Analytical

You are running **Pass 1 (analytical)** of a Two-Pass Axis Engineering review. Fresh context,
no prior knowledge of this project. Another agent is running Pass 2 concurrently on the same
target with adversarial lenses — you will never see its output and it will never see yours.
Do not try to guess what it will find or leave gaps for it to fill.

## Repository

`/Users/lotusboy/workspaces/object-permanence`

All paths below are relative to that root. Read files directly; do not rely on the README's
description of what a script does.

## What this project is

Permanence is a tool that gives an AI coding assistant persistent memory of a project across
sessions. The user's notes live as plain markdown in a directory (`~/permanence` by default),
organised into "streams" — one folder per ongoing project, each holding `PROJECT.md`,
`LOG.md`, `PEOPLE.md`, `QUESTIONS.md`. A registry maps a workspace path to its stream.
Shell scripts in `runtime/` wire this into Claude Code via hooks, slash commands and a
scheduled nightly job. The repo is cloned once to `~/permanence` and re-initialised as the
user's own private git repo, so the machinery and the user's notes share one directory.

## Your target

| Read | Why |
|---|---|
| `runtime/*.sh` | The machinery itself — this is the primary target |
| `.githooks/pre-commit`, `.githooks/post-commit` | Guards that run on the user's own notes |
| `SPEC.md` | The invariants the machinery *claims* to uphold |
| `README.md`, `QUICKSTART.md` | The promises made to a new user |
| `runtime/commands/*.md` | The `/perma-*` instructions Claude actually executes |
| `_meta/REGISTRY.md`, `_meta/GROUPS.md` | The data shapes the scripts parse |

**Do not review `example/`** — fictional demo content, deliberately out of scope.

## Your three lenses

**1. First Principles.** What is this machinery fundamentally *for*? Strip away the naming and
the framing. Given that purpose, does the shape as built serve it? Name any component that
does not earn its place, and any part of the stated purpose that nothing implements. Pay
attention to whether a mechanism's actual guarantee matches the guarantee its documentation
claims — "instruction-following, not enforcement" is a materially different promise from
"it happens automatically".

**2. MECE.** Test the decomposition for gaps and overlaps. Specific questions worth answering,
though not the only ones: There appear to be several context-loading paths (a SessionStart
hook, a UserPromptSubmit hook, a `CLAUDE.md` block, an `AGENTS.md` block, and a documented
manual fallback) — are they mutually exclusive, or do they overlap and duplicate? Do
`REGISTRY.md` and `GROUPS.md` answer genuinely different questions or the same question
twice? Do the canonical stream files partition a project's state without gap? Is the
opt-in/always-on split of the extras coherent, or arbitrary?

**3. Genba — go to the actual place.** Every claim you make must be traced to the line that
produces the behaviour, never to a comment describing it. This codebase is unusually
comment-rich; the comments are a hypothesis, the code is the evidence. Specifically verify by
reading the code, not the prose: what `install.sh` actually writes to files it does not own
(`~/.claude/settings.json`, `~/.claude/CLAUDE.md`, global `AGENTS.md` paths, the OS
scheduler); how `resolve-stream.sh` parses the registry table and what inputs would defeat
that parse; what `update.sh` actually checks out and commits; whether `SPEC.md`'s invariants
are each enforced somewhere in code, merely asserted in prose, or contradicted.

## Ledger

Maintain a **Verified / Unknown** ledger. Anything you could not check — a scheduler backend
for an OS you are not on, a tool you cannot run, behaviour that depends on Claude Code
internals — goes in Unknown. Do not assert it either way.

## Report back

Write your findings to:

`axis/runs/2026-08-30-object-permanence-two-pass/04-pass1-output.md`

Structure, in this order:

1. **BLUF** — one paragraph. What is the state of this machinery, analytically?
2. **First Principles findings**
3. **MECE findings**
4. **Genba findings**
5. **Verified / Unknown ledger**
6. **One-sentence verdict** on whether the machinery's shape matches its stated purpose.

Number every finding (`FP-1`, `M-1`, `G-1`) so a later merge agent can reference it. Every
finding needs a `file:line` citation and a one-line statement of the concrete consequence.
Around 1,200 words; go longer only if you have genuine signal, and do not pad to reach a
count — manufacturing findings on a small codebase is an explicit anti-pattern.

**Scope discipline:** Pass 1 reports **what is**, not what should be. Do not propose fixes —
recommendations are the merge agent's job. Describing a defect precisely is in scope; writing
the patch is not.

**Andon:** if you find a path that can destroy a user's notes or git history, or a write to
shared machine state that could break a tool other than Permanence, stop and headline it at
the top of your BLUF before continuing.
