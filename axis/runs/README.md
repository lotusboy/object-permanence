# Axis runs

One folder per protocol run, named `<YYYY-MM-DD>-<subject>-<protocol>`.

Each run keeps its prompts *and* its raw outputs, so a reader can judge the findings against
the exact instructions that produced them. The prompts are committed before the agents run;
the outputs are whatever came back, unedited.

## File convention

| File | What it is |
|---|---|
| `00-contract.md` | The Axis Contract for the run — axes, target, structure, evidence rule, stop condition |
| `01-pass1-prompt.md` | Pass 1 (analytical) instructions |
| `02-pass2-prompt.md` | Pass 2 (adversarial) instructions |
| `03-synthesis-prompt.md` | Merge instructions |
| `04-pass1-output.md` | Pass 1 result, verbatim |
| `05-pass2-output.md` | Pass 2 result, verbatim |
| `06-synthesis.md` | Merged, deduplicated, severity-ordered findings |

## Isolation rule

Each of the three agents runs in a **fresh context**. Pass 2 never sees Pass 1. The synthesis
agent reads only the two pass outputs — never the reviewed artefacts, and never a prior
synthesis. That isolation is what makes the convergence rate meaningful: when both passes
independently reach the same finding, it is genuine agreement rather than an echo.
