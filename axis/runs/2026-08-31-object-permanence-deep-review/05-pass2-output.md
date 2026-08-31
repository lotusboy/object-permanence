# Pass 2 — Adversarial Report

**Target:** `/Users/lotusboy/workspaces/object-permanence` @ `v1.0.5`  
**Lenses:** Pre-mortem · Chaos Engineering · Poka-yoke  
**Auditor:** Axis Pass 2 Agent (Adversarial)

---

## 1. BLUF

No P0 data-loss bugs or uncontrolled write vectors remain in v1.0.5. However, adversarial failure testing uncovered one live runtime crash (`cogdebt-scan.sh` on non-Python repos), a critical race condition in the cross-project events cursor (`events-listen.sh` advancing cursors prior to delivery), and a launchd PATH vulnerability that breaks unattended consolidation when Claude is installed via VS Code extensions.

---

## 2. Pre-Mortem Findings

### PM-1: The Silent Event Loss Failure
* **Artefact:** `runtime/events-listen.sh:31`, `runtime/stop-listen.sh:60`
* **Scenario:** Session A emits a critical architecture blocker to `all`. Session B opens, triggering `events-listen.sh`. The script executes:
  ```bash
  printf '%s\n' "$total" > "$cursorfile"
  ```
  Immediately after writing the cursor, the Python parser process is interrupted (OOM, terminal close, malformed JSON escape). The hook exits without outputting the message. On the next turn, the cursor already equals `total`. The message is permanently lost to Session B.
* **Severity:** **P2**

### PM-2: Unattended Nightly Scheduler PATH Failure
* **Artefact:** `runtime/nightly-consolidate.sh:8, 43`
* **Scenario:** A user installs Claude Code via the VS Code extension or `nvm`. `install.sh` wires `launchd`. When launchd fires at 05:30, it runs with a bare `PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"`. The binary resides at `~/.vscode/extensions/.../native-binary/claude`. `command -v claude` fails, logging `ERROR: claude CLI not found on PATH` every morning.
* **Severity:** **P1** (Confirmed by live log inspection).

---

## 3. Chaos Engineering Findings

### Chaos-1: Live Execution Crash on Non-Python Repositories
* **Artefact:** `runtime/cogdebt-scan.sh:65, 74`
* **Live Test:** Initialized a scratch repo with only `README.md` and ran `bash runtime/cogdebt-scan.sh /tmp/test-repo`.
* **Observed Failure:**
  ```text
  Traceback (most recent call last):
    File "<stdin>", line 3, in <module>
    File "<stdin>", line 3, in <genexpr>
  ValueError: invalid literal for int() with base 10: ''
  ```
  `src` was empty, causing `read -r big bigf` to assign `""` to `big`. The embedded Python script threw `ValueError` on `int(big)`, producing an empty scan and a broken report.
* **Severity:** **P1**

### Chaos-2: Custom `PERMA_DIR` Permission Denial
* **Artefact:** `runtime/nightly-consolidate.sh:95`
* **Scenario:** When `PERMA_DIR=/custom/path`, Claude runs with `--allowedTools "Write($HOME/permanence/.consolidation/*)"`. When the model attempts `Write(/custom/path/.consolidation/REPORT-*.md)`, the tool call is denied by the security envelope.
* **Severity:** **P1**

---

## 4. Poka-Yoke Findings

### PY-1: Missing Default Numeric Guards in Shell-to-Python Handshake
* **Artefact:** `runtime/cogdebt-scan.sh:65`
* **Analysis:** The shell script passes positional parameters into Python without defaulting unset variables. `big="${big:-0}"` and `srcloc="${srcloc:-0}"` are required poka-yoke guards.

### PY-2: Non-Atomic Cursor Advances
* **Artefact:** `runtime/events-listen.sh:25-33`
* **Analysis:** Advancing state *before* successful consumption violates standard transactional queuing. State must be updated only upon verified emission to stdout.

---

## 5. Verified / Unknown Ledger

### Verified by Execution
* Executed `cogdebt-scan.sh` on non-Python repo → reproduced Python `ValueError` traceback.
* Checked `nightly-consolidate.log` on live machine → confirmed PATH failure at 05:30.
* Executed `generate-contents.sh` on directories with whitespace → observed word splitting in subshell loop.

### Unknown
* Behavior on native Windows schtasks when user path contains non-ASCII Unicode characters.

---

## 6. One-Sentence Verdict

The core security and data-safety boundaries hold, but script-level error recovery and path assumptions require defensive hardening against non-standard environments.
