# Synthesis — Merge Pass 1 + Pass 2

You are the **merge agent** for a Two-Pass Axis Engineering review. Pass 1 (analytical) and
Pass 2 (adversarial) ran concurrently in isolated contexts, neither seeing the other. Your job
is to deduplicate, reconcile and produce one severity-ordered finding list.

## Inputs — these two files ONLY

| Input | Path |
|---|---|
| **Pass 1 (analytical)** | `axis/runs/2026-08-30-object-permanence-two-pass/04-pass1-output.md` |
| **Pass 2 (adversarial)** | `axis/runs/2026-08-30-object-permanence-two-pass/05-pass2-output.md` |

Relative to `/Users/lotusboy/workspaces/object-permanence`.

**Do NOT read the reviewed repository.** Not `runtime/`, not `SPEC.md`, not the README, not
the contract or the prompt files, not `.git`. Each pass already cites `file:line` for its own
findings; your job is to reconcile *across the two reports*, not to re-review the code. Going
to the source would re-introduce exactly the contamination this third pass exists to avoid,
and would let you smuggle in findings neither pass actually made.

If a finding's citation looks wrong to you, say so in the notes column — do not go and check.

## Merge contract

From the Two-Pass Strategy protocol:

```
DEDUPE KEY:   (artefact, symptom, root-cause-class). Two findings about the same artefact
              with the same root cause merge into one, and the merged entry names both
              origins.

SEVERITY:     max(pass1_severity, pass2_severity). If Pass 2 escalates a Pass 1 finding,
              take the higher.

CONFLICTS:    if Pass 2 contradicts Pass 1, prefer Pass 2 where its evidence is stronger
              (more citations, verbatim snippets) — it read the code fresh without
              anchoring. Where Pass 1's evidence is stronger, say so and prefer Pass 1.
              Record every conflict explicitly; do not silently resolve one.

UNIQUE:       anything found by only one pass is included as-is, attributed to that pass.

TRACEABILITY: every finding in your output must be traceable to Pass 1, Pass 2, or both.
              A finding traceable to neither is confabulation — the known failure mode of
              this merge step. If you catch yourself adding one, delete it.
```

Pass 1 was instructed **not** to assign severities; assign them yourself from the symptom and
projected consequence it describes. Pass 2 was instructed to self-label P0–P3; respect its
labels unless Pass 1 supplies evidence that justifies escalation.

Severity: **P0** (Andon — data loss, or breaking a tool other than Permanence; must be fixed
before anyone else installs), **P1**, **P2**, **P3**.

## Output

Write to `axis/runs/2026-08-30-object-permanence-two-pass/06-synthesis.md`.

Structure:

1. **Header table** — date; target; Pass 1 finding count; Pass 2 finding count; merged count
   with the severity breakdown; Andon status; convergence rate (findings independently raised
   by both passes ÷ merged total, as a percentage).
2. **Verdict** — one decisive paragraph. Is this safe for a stranger to install today, safe
   with caveats, or does it need work first? Commit to an answer.
3. **Findings** — severity-ordered P0 → P3. Each with: ID; origin (which pass, and that
   pass's own label where it had one); artefact and line numbers as cited; symptom and
   failure mode; root cause; severity; recommendation. Where both passes converged, name both
   origins and say what each contributed.
4. **Conflicts and disagreements** — anywhere the passes contradicted each other, what you
   preferred, and why. If there were none, say so plainly; an honest zero is a real result and
   is itself interesting, because two independent passes agreeing on everything is unusual.
5. **Combined ledger** — merged Verified / Unknown. Anything either pass could not check
   stays Unknown.
6. **Apply order** — the order fixes should be made, noting which fixes resolve others as a
   side-effect.

## Calibration

Do not inflate. If the two passes between them produced few real findings, a short synthesis
saying so is the correct output. Convergence rate is a genuine measurement — report what you
actually observe, whether that is 5% or 50%. Resist the pull to make the review look
productive; the value of this protocol depends on the number being honest.
