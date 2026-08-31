# Pass 1 — Analytical Report

**Target:** `/Users/lotusboy/workspaces/object-permanence` @ `v1.0.5`  
**Lenses:** First Principles · MECE · Genba  
**Auditor:** Axis Pass 1 Agent (Analytical)

---

## 1. BLUF

Object Permanence v1.0.5 is an exceptionally well-structured, lean implementation of externalised working memory. The v1.0.3 patches effectively neutralized prior P0 data loss vectors in `install.sh` and `make-backup.sh`. The core data model (`PROJECT.md`, `LOG.md`, `PEOPLE.md`, `QUESTIONS.md`) cleanly partitions project state. However, analytical inspection reveals two notable structural gaps: (1) `nightly-consolidate.sh`'s scoped tool grant breaks when a user exercises the documented `PERMA_DIR` override, and (2) `cogdebt-scan.sh` assumes every monitored codebase contains Python files, failing on non-Python repositories.

---

## 2. First Principles Findings

### FP-1: Custom `PERMA_DIR` breaks unattended permission grant
* **Artefact:** `runtime/nightly-consolidate.sh:95, 98`
* **Analysis:** `SPEC.md` and `install.sh` explicitly support non-standard install paths via `PERMA="${PERMA_DIR:-$HOME/permanence}"`. However, `nightly-consolidate.sh` passes hardcoded string literals to Claude CLI's `--allowedTools`:
  ```bash
  "Write($HOME/permanence/.consolidation/*)" "Write(~/permanence/.consolidation/*)" \
  "Bash(git -C $HOME/permanence log:*)" "Bash(git -C ~/permanence log:*)"
  ```
  If `PERMA_DIR` is set to `/opt/permanence`, the model's write attempts to `.consolidation/` are denied by Claude Code's permission boundary, causing the nightly pass to abort with no report (`exit 70`).
* **Consequence:** The stated promise of portable installation via `PERMA_DIR` fails for scheduled unattended operations.

### FP-2: Cognitive debt scan assumes Python-only codebases
* **Artefact:** `runtime/cogdebt-scan.sh:61-65, 74`
* **Analysis:** The cognitive debt model is designed as a language-agnostic qualitative proxy (bus factor, AI authorship, doc/code ratio). Yet `metrics_json()` hardcodes Python file discovery (`git ls-files '*.py'`) and Python test function grep (`def test_`). If a repository has no Python files, `srcloc` evaluates to 0 and `big` evaluates to empty string `""`, leading to an unhandled `ValueError` in the Python helper.
* **Consequence:** Cognitive debt monitoring fails for polyglot or non-Python engineering assets.

---

## 3. MECE Findings

### M-1: Clean partition of Tier 1 vs Tier 2 configuration
* **Artefact:** `runtime/install.sh:94-118`, `docs/OTHER-TOOLS.md:18-34`
* **Analysis:** The decomposition between Claude Code (Tier 1: native hooks in `~/.claude/settings.json`) and other AI agents (Tier 2: global `~/.config/agents/AGENTS.md`, `~/.codex/AGENTS.md`) is completely mutually exclusive and collectively exhaustive. Global config files are updated with delimited blocks; project-committed `AGENTS.md` files are strictly untouched, preserving Invariant 1 (One-way flow).

### M-2: REGISTRY.md vs GROUPS.md boundary
* **Artefact:** `_meta/REGISTRY.md:1-13`, `_meta/GROUPS.md:1-15`
* **Analysis:** The two registries answer completely distinct questions: `REGISTRY.md` maps workspace path → private stream (internal working memory); `GROUPS.md` maps workspace path → outward programme reporting (stakeholder status). Neither duplicates the other.

---

## 4. Genba Findings

### G-1: Word-splitting on directory paths in `generate-contents.sh`
* **Artefact:** `runtime/generate-contents.sh:57`
* **Analysis:** `full_index()` iterates over directory paths using command substitution:
  ```bash
  for d in $(find . \( -name .git -o -name .consolidation \) -prune -o -maxdepth 2 -mindepth 1 -type d -print | sed 's|^\./||' | sort); do
  ```
  If a stream or directory contains spaces (e.g. `example/home/guest bedroom`), the shell splits on whitespace, passing fractured directory fragments to `find "$d"`.

### G-2: Fallback `remote add` syntax failure in `update.sh`
* **Artefact:** `runtime/update.sh:44-46`
* **Analysis:**
  ```bash
  git -C "$PERMA" remote get-url _machinery >/dev/null 2>&1 \
    && git -C "$PERMA" remote set-url _machinery "$SRC" \
    || git -C "$PERMA" remote add _machinery "$SRC"
  ```
  If `get-url` succeeds (remote exists) but `set-url` fails, execution falls into `remote add`, which fails with `fatal: remote _machinery already exists`, masking the actual error.

### G-3: Unquoted `$FILES` expansion in CI workflow
* **Artefact:** `.github/workflows/ci.yml:48`
* **Analysis:** `FILES=$(git ls-files '*.md' '*.sh' '*.py' '*.txt' ':!:example/**')` is passed unquoted to `grep`. In shells without word-splitting (e.g. zsh) or when filenames contain whitespace, `grep` errors with `File name too long`.

---

## 5. Verified / Unknown Ledger

### Verified (Checked against actual files & code)
* `install.sh` block-merge integrity checks against `CLAUDE.md` and `AGENTS.md` (verified).
* `make-backup.sh` pre-flight dirty check and retention pruning guard (verified).
* `resolve-stream.sh` longest-prefix match and trailing slash normalization (verified).
* `perma-search.py` on-CPU ONNX MiniLM indexing logic (verified).

### Unknown (Not verified in this pass)
* Behavior of `schtasks.exe` on native Windows environments (analyzed via source, not run on Windows).
* Multi-month accumulation performance of `events.jsonl` under high concurrency.

---

## 6. One-Sentence Verdict

The architecture is clean, disciplined, and genuinely serves its core purpose, requiring only minor parameterization and default-value hardening across its edge scripts.
