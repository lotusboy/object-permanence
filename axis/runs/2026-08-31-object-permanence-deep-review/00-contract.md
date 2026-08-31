# Axis Contract — Object Permanence v1.0.5 Deep Review

| | |
|---|---|
| **Date** | 2026-08-31 |
| **Protocol** | Two-Pass Strategy (analytical → adversarial → merge) |
| **Subject** | Object Permanence machinery in `lotusboy/object-permanence` at v1.0.5 |
| **Agents** | 3, each fresh-context and blind to the others |

## Context

Following the v1.0.3 hardening release (which addressed 19 findings from the 2026-08-30 audit across data loss, lock hygiene, and scheduler path splitting), this run performs a deep re-audit of the consolidated codebase at v1.0.5 (including README polish, product rebrand, cross-platform scheduling, and live install integration).

## The contract

```
AXES:         Pass 1  — First Principles + MECE + Genba          (analytical: what IS)
              Pass 2  — Pre-mortem + Chaos Engineering + Poka-yoke (adversarial: what BREAKS)
              Merge   — no new lenses; dedupe key + severity rules only

TARGET:       runtime/*.sh                 (machinery: install, session, events, schedule,
                                            update, consolidate, backup, cogdebt, search)
              runtime/search/perma-search.py
              .githooks/pre-commit, post-commit
              SPEC.md                      (the invariants the machinery claims to uphold)
              README.md, QUICKSTART.md     (the promises made to a new user)
              docs/*.md                    (UPGRADE.md, OTHER-TOOLS.md)
              runtime/commands/*.md        (the /perma-* instructions Claude executes)
              _meta/REGISTRY.md, _meta/GROUPS.md
              EXCLUDED: example/           (fictional demo content, out of scope)

STRUCTURE:    Pyramid — verdict first, then findings, then evidence

EVIDENCE:     every finding cites file:line. A finding without a citation is dropped at merge.
              Claims about behaviour must be traced to the line producing it.

ASSUMPTIONS:  each pass maintains a Verified / Unknown ledger.

STOP:         Andon — halt and headline immediately on either of:
                • data loss (paths deleting or overwriting notes/history)
                • writes to shared machine state breaking tools other than Permanence
```

## Handle rationale

**Pass 1 — analytical.** *First Principles* tests whether the refined architecture matches the core mission of externalized working memory across sessions. *MECE* checks boundaries between tiers (Claude Code vs `AGENTS.md` standard vs manual pointers) and data scopes. *Genba* audits line-by-line implementations in shell scripts, Python helpers, and git hooks.

**Pass 2 — adversarial.** *Pre-mortem* hypothesizes silent failures in automated cron/launchd runs, multi-session collisions, and edge-case repo configurations. *Chaos Engineering* tests environments missing Python modules, non-Python target repos, empty git trees, and unquoted paths with spaces. *Poka-yoke* checks where guards are missing or where errors fail quietly instead of failing loud.

**Merge.** Mechanical reconciliation: dedupe key `(artefact, symptom, root-cause-class)`, `severity = max(pass1, pass2)`.
