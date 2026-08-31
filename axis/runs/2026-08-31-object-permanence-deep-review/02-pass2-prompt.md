# Pass 2 — Adversarial

You are running **Pass 2 (adversarial)** of a Two-Pass Axis Engineering review. Fresh context,
no prior knowledge of this project. Another agent ran Pass 1 on the same target with
analytical lenses — you will never see its output and it will never see yours.

## Repository

`/Users/lotusboy/workspaces/object-permanence`

All paths below are relative to that root.

## What this project is

Object Permanence is an externalised working memory system in plain markdown + git. It holds
state across sessions in streams (`PROJECT.md`, `LOG.md`, `PEOPLE.md`, `QUESTIONS.md`). A
registry maps workspaces to streams. Shell scripts in `runtime/` wire this into Claude Code
via hooks, slash commands, and a nightly consolidation job.

## Your target

Same target set as Pass 1:
- `runtime/*.sh`, `runtime/search/perma-search.py`
- `.githooks/pre-commit`, `.githooks/post-commit`
- `SPEC.md`, `README.md`, `QUICKSTART.md`, `docs/*.md`
- `runtime/commands/*.md`, `_meta/REGISTRY.md`, `_meta/GROUPS.md`
- **EXCLUDED:** `example/`

## Your three lenses

**1. Pre-mortem.** Assume the tool has failed in production. A user installed it, worked for a
month, and lost data or had their assistant silently stop loading memory. How did it happen?
Trace the failure paths backwards from the consequence to the code:
- Stale locks, broken event buses, denied tool calls in headless runs.
- Missing dependencies or unhandled platform quirks.

**2. Chaos Engineering.** What happens when the environment misbehaves?
- Non-Python repositories passed to scripts expecting Python.
- Paths with spaces or non-ASCII characters.
- Non-standard install paths (`PERMA_DIR`).
- Race conditions during event delivery or multi-session writes.
- Network outages, dead links, or missing binaries on non-interactive PATHs.

**3. Poka-yoke (Mistake-proofing).** Where can a user or model make an error that code could
have made impossible?
- Scripts that report success when intermediate steps fail.
- Non-atomic updates to cursors or lockfiles.
- Command injections or heredoc vulnerabilities.

## Ledger

Maintain a **Verified / Unknown** ledger. Anything tested live vs reasoned hypothetically.

## Report back

Write your findings to:
`axis/runs/2026-08-31-object-permanence-deep-review/05-pass2-output.md`

Structure:
1. **BLUF** — one paragraph adversarial summary.
2. **Pre-mortem findings** (`PM-1`, `PM-2`...)
3. **Chaos Engineering findings** (`Chaos-1`, `Chaos-2`...)
4. **Poka-yoke findings** (`PY-1`, `PY-2`...)
5. **Verified / Unknown ledger**
6. **One-sentence verdict**
