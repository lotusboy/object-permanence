---
description: "What this Permanence can do — every installed /perma-* command, and which background machinery is actually switched on for this machine. Trigger phrases: \"what can Permanence do\", \"Permanence help\"."
---

# Permanence — Help

Show me what this Permanence can do, and what is actually running.

## How to run it

1. Run `~/permanence/runtime/perma-help.sh` and show me its output. It reads the **installed** commands' own
   descriptions and probes the live machine (launchd jobs, wired hooks, the search index, the update
   source), so it reports the real state rather than a list that drifts. Don't rewrite or summarise it —
   the grouping and the ✅/○ marks are the point.
2. If the script is missing, fall back to listing `~/.claude/commands/perma-*.md` with each file's
   `description:` line, and say the enabled/disabled detail wasn't available.
3. **If anything shows as off (`○`), and only if I ask**, explain what enabling it would do and what it
   would cost. Don't switch anything on unprompted — several of these are machine-wide, and that's my call.

Answer follow-up questions about any single command from its own file in `~/.claude/commands/`, rather
than from memory — the file is the truth.

## Guardrails

- **Read-only.** This changes nothing: no files, no settings, no launchd jobs.
- **Report, don't sell.** If something's off, say so plainly and leave it off.
