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

Object Permanence is a tool that gives an AI assistant persistent memory of projects across
sessions using plain markdown in a repository (`~/permanence` by default), organised into
streams (`PROJECT.md`, `LOG.md`, `PEOPLE.md`, `QUESTIONS.md`). A registry maps workspace paths
to streams. Shell scripts in `runtime/` wire this into Claude Code via hooks, slash commands,
and a scheduled nightly job.

## Your target

| Read | Why |
|---|---|
| `runtime/*.sh` | The machinery itself — this is the primary target |
| `runtime/search/perma-search.py` | Local semantic search implementation |
| `.githooks/pre-commit`, `.githooks/post-commit` | Guards that run on notes |
| `SPEC.md` | The invariants the machinery claims to uphold |
| `README.md`, `QUICKSTART.md` | The promises made to a new user |
| `docs/*.md` | Upgrade and other-tools guidance |
| `runtime/commands/*.md` | The `/perma-*` instructions Claude executes |
| `_meta/REGISTRY.md`, `_meta/GROUPS.md` | The data shapes parsed |

**Do not review `example/`** — fictional demo content, deliberately out of scope.

## Your three lenses

**1. First Principles.** What is this machinery fundamentally *for*? Given that purpose, does
the shape as built serve it? Name any component that does not earn its place, and any part of
the stated purpose that nothing implements. Test whether claims in `SPEC.md` are actively
realized in code.

**2. MECE.** Test the decomposition for gaps and overlaps. Are Tier 1 (Claude Code) and Tier 2
(`AGENTS.md`) clean and non-conflicting? Do `REGISTRY.md` and `GROUPS.md` partition concerns
without overlap? Does the canonical stream structure (`PROJECT`, `LOG`, `PEOPLE`, `QUESTIONS`)
cover project state without gaps?

**3. Genba — go to the actual place.** Every claim you make must be traced to the line that
produces the behaviour, never to a comment describing it. Audit line-by-line: what `install.sh`
wires into `settings.json` and global configs; what `nightly-consolidate.sh` executes; what
`resolve-stream.sh` parses; how `perma-search.py` queries ChromaDB.

## Ledger

Maintain a **Verified / Unknown** ledger for items checked vs assumptions.

## Report back

Write your findings to:
`axis/runs/2026-08-31-object-permanence-deep-review/04-pass1-output.md`

Structure:
1. **BLUF** — one paragraph analytical summary.
2. **First Principles findings** (`FP-1`, `FP-2`...)
3. **MECE findings** (`M-1`, `M-2`...)
4. **Genba findings** (`G-1`, `G-2`...)
5. **Verified / Unknown ledger**
6. **One-sentence verdict**
