# Axis Contract — Permanence machinery, Two-Pass review

| | |
|---|---|
| **Date** | 2026-08-30 |
| **Protocol** | Two-Pass Strategy (analytical → adversarial → merge) |
| **Subject** | The Permanence machinery in `lotusboy/object-permanence` at v1.0.2 |
| **Agents** | 3, each fresh-context and blind to the others |

## Why Two-Pass rather than single-pass

Per the protocol's own selector, a single pass with a handle cocktail suits routine review.
Two passes are for pre-production audits and anything touching shared infrastructure. This
machinery qualifies on both counts: `install.sh` writes to `~/.claude/settings.json`,
`~/.claude/CLAUDE.md`, global `AGENTS.md` files and the OS scheduler — shared, machine-wide
state that other tools also own. A silent defect there does not fail loudly; it quietly
mis-wires someone's assistant.

## The contract

```
AXES:         Pass 1  — First Principles + MECE + Genba          (analytical: what IS)
              Pass 2  — Pre-mortem + Chaos Engineering + Poka-yoke (adversarial: what BREAKS)
              Merge   — no new lenses; dedupe key + severity rules only

TARGET:       runtime/*.sh                 (the machinery: install, session, events, schedule,
                                            update, consolidate, backup, cogdebt, search)
              .githooks/pre-commit, post-commit
              SPEC.md                      (the invariants the machinery claims to uphold)
              README.md, QUICKSTART.md     (the promises made to a new user)
              runtime/commands/*.md        (the /perma-* instructions Claude actually executes)
              EXCLUDED: example/           (fictional demo content, not machinery)

STRUCTURE:    Pyramid — verdict first, then findings, then evidence

EVIDENCE:     every finding cites file:line. A finding without a citation is dropped at merge.
              Claims about behaviour must be traced to the line that produces it, not inferred
              from a comment or a doc.

ASSUMPTIONS:  each pass maintains a Verified / Unknown ledger. Anything the agent could not
              check (another OS's scheduler backend, a tool it cannot run) goes in Unknown
              rather than being asserted.

STOP:         Andon — halt and headline immediately on either of:
                • data loss (a path that can delete or overwrite a user's notes or history)
                • a write to shared machine state that could break a tool other than Permanence
```

## Handle rationale

**Pass 1 — analytical.** *First Principles* asks what this machinery is fundamentally for and
whether its shape serves that. *MECE* tests whether the pieces divide the job without gap or
overlap — three separate context-loading mechanisms, for instance, either partition cleanly or
they don't. *Genba* forces every claim back to the actual line of shell, not the comment above
it; this codebase is unusually comment-rich, which is exactly the condition under which a
reviewer starts believing the prose instead of the code.

**Pass 2 — adversarial.** *Pre-mortem* assumes the tool has already failed a user badly and
works backwards. *Chaos Engineering* asks what happens when the environment misbehaves —
no `python3`, no network, a full disk, an interrupted write, two sessions at once. *Poka-yoke*
asks where a mistake is possible that a guard could have made impossible. Deliberately
excludes the Pattern-oriented axis: SOLID and Fowler's have little purchase on shell scripts.

**Merge.** No lenses. Mechanical application of the protocol's dedupe key
`(artefact, symptom, root-cause-class)`, `severity = max(pass1, pass2)`, and Pass-2-wins on
contradiction where its evidence is stronger.

## Isolation

Pass 1 and Pass 2 run **concurrently** in separate contexts, so neither can anchor on the
other. The synthesis agent reads **only** `04-pass1-output.md` and `05-pass2-output.md` — not
the repo, not this contract's target list, not any earlier draft. Convergence between the two
passes is therefore evidence, not echo.

## Known bias to declare

The reviewed repo and the reviewing methodology share an author, and the session commissioning
this run has spent the evening editing the same files. That is precisely why all three agents
are fresh-context: the conversation's own conclusions must not leak into the findings. Any
finding that merely restates something already known in that conversation should be treated as
weaker evidence, not stronger.
