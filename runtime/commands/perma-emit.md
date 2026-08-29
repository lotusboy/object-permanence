---
description: Emit a Permanence event from THIS project to other open sessions — a semi-real-time note that something interesting happened here, delivered into other projects' context (never their files). Pub/sub: the emitter never sees its own event echoed back.
---

# Permanence — Emit event

Use when something in **this** project is worth other open projects knowing **now**, without waiting for them to re-read Permanence at their next session start.

1. **Target:** default `all` (every other open session); or a single stream name (e.g. `home/kitchen`) if only one project cares.
2. **Message:** one line — *what happened* + *why it matters to the others*. Gentle, accurate register (it sits briefly in the shared outbox).
3. **Emit:** run `~/permanence/runtime/emit-event.sh <target> "<message>"` — the source stream is auto-resolved from the current workspace via the registry.
4. **Confirm** to the user what was emitted and to whom.

**Rules:**
- Events flow into other sessions' **attention** only — never write them into a project repo's files (one-way flow holds).
- **Never emit secrets or personal/confidential payloads.** Emit a *pointer*, not the sensitive content — e.g. "the kitchen-units decision changed; see `home/kitchen` LOG", not the data itself.
- Signal, not chatter — emit material moves (decisions, landings, blockers), not routine progress.
- Delivery is semi-real-time: a listening session picks it up on its **next action** (next prompt / tool run). It will not interrupt a frozen idle screen — that's the ceiling.
- **Opt-in:** *emitting* always works, but *receiving* needs the `UserPromptSubmit` events hook enabled in `~/.claude/settings.json` (see the `install.sh` "events" note). Without it, events sit in the outbox unread.
