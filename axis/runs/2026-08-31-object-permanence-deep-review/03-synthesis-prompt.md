# Synthesis — Merge Pass 1 and Pass 2

You are the **Synthesis Agent** for an Axis Engineering Two-Pass review. Your job is to
reconcile and merge `04-pass1-output.md` (analytical) and `05-pass2-output.md` (adversarial)
into a single, authoritative findings report.

## Target

The Object Permanence codebase at `v1.0.5` (`/Users/lotusboy/workspaces/object-permanence`).

## Your inputs

Read **only**:
1. `axis/runs/2026-08-31-object-permanence-deep-review/04-pass1-output.md`
2. `axis/runs/2026-08-31-object-permanence-deep-review/05-pass2-output.md`

**Do not re-read the repository itself.** You are synthesizing the two reports as written,
measuring their convergence, and producing a unified priority ledger.

## Reconciliation rules

1. **Deduplication key:** `(artefact, symptom, root-cause-class)`. Two findings that name the
   same artefact, failure mode, and root cause are merged into one finding.
2. **Convergence tracking:** Record which findings were raised by Pass 1, which by Pass 2, and
   which were raised independently by both. Calculate the convergence rate:
   `Convergence = (Both) / (Total Unique Findings)`.
3. **Severity arbitration:**
   - `severity = max(pass1_severity, pass2_severity)`
   - P0: Andon items (data loss, deleting user notes, corrupting shared machine state)
   - P1: Silent failures in core loops, broken background tasks, crashes in active tooling
   - P2: Edge-case bugs, non-atomic state updates, formatting or portability flaws
   - P3: Minor documentation inconsistencies or non-blocking polish
4. **Contradiction rule:** Where Pass 1 and Pass 2 disagree on a fact, prefer the pass that
   provides live-execution or exact code-trace evidence.

## Report back

Write your merged report to:
`axis/runs/2026-08-31-object-permanence-deep-review/06-synthesis.md`

Structure:
1. **Header table** (Date, Target, Pass 1 count, Pass 2 count, Merged count by P0–P3, Andon status, Convergence rate)
2. **Verdict** (One concise paragraph on production fitness and safety)
3. **Findings** (P0 through P3, each with Origin, Artefact, Symptom, Root cause, Severity, and Actionable recommendation)
4. **Convergence analysis**
5. **Verified / Unknown reconciled ledger**
