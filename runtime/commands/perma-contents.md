# /perma-contents — regenerate Permanence's file inventory

Regenerate Permanence's `CONTENTS.md` inventory files. Argument: `$ARGUMENTS` — `local` (default), `full`, or a stream path like `home/kitchen`.

**Navigation reality (learned the hard way):** clickable links keep breaking in VS Code — the Claude **chat panel** rewrites `file://` into dead `vscode-webview://` URLs, and source view shows raw markdown. The reliable way to *click* Permanence files is the **Explorer**, not a links file. So this command regenerates a dated *inventory*; it does **not** try to be a clickable chat menu.

1. **Resolve scope.**
   - `local` (or empty): resolve the current working directory through `~/permanence/_meta/REGISTRY.md` (longest-prefix match, same rule as `runtime/session-start.sh`). If the cwd is unregistered or maps to `perma-meta`, fall back to `full` and say so in one line.
   - `full`: the whole Permanence.
   - A path (e.g. `home/bathroom`): that stream directly.
2. **Regenerate** by running `~/permanence/runtime/generate-contents.sh <stream>` (or with no argument for `full`/all). This rewrites the relevant `CONTENTS.md` files — they are derived, gitignored output; never hand-edit them.
3. **Chat reply — plain text, NO links.** Confirm the scope regenerated + the file path (`~/permanence/<stream>/CONTENTS.md`). If an in-chat glance helps, list files as **plain text** (filename + date), grouped by folder — but **never** markdown or `file://` links: the chat panel mangles them into unusable `vscode-webview://` URLs. Keep it short.
4. **Point at the reliable surfaces, briefly:**
   - **To click files → the Explorer.** Add `~/permanence` as a folder to the VS Code window (File → Add Folder to Workspace). Safe — not a symlink, not in any repo, pure IDE visibility. This is the no-fuss navigation route.
   - **The inventory file** lives at `~/permanence/<stream>/CONTENTS.md`, refreshed on every Permanence commit. It's a **plain dated list, no links** — read it for the "what's here + when" overview; click the files themselves in the Explorer.

**File format (for `generate-contents.sh` output only):** plain markdown — `- <relative-path> — <date>`, newest-first per stream, grouped by folder in the full index. **No links, deliberately.** Clickable links were removed after failing across every surface: VS Code preview sanitizes `file://` (renders non-clickable), the chat panel rewrites it to dead `vscode-webview://`, and relative links mis-resolve across workspaces. Navigation is the Explorer; this file is a readable inventory, nothing more.

Read-only apart from the generated `CONTENTS.md` files. Never write anything else, never commit.
