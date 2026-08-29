# GROUPS — project → programme group

> The machine-read map of **which projects report into a shared programme folder**. Same one-way
> pointer as [REGISTRY.md](REGISTRY.md): this file (in Permanence) references your projects — never the
> reverse.
>
> `REGISTRY.md` answers *"which Permanence stream does this workspace load?"*. This file answers *"which
> programme does this workspace report into, and as what?"*. Different questions, different lifecycles,
> deliberately separate files.
>
> Read by `/perma-shutdown`: it resolves cwd → group + role, then follows that group's **task doc**,
> which lives in the target repo. **Optional** — leave the tables empty (or delete this file) and the
> shutdown step skips silently. You only need this if one programme spans more than one repo.

## What a group is for

A programme is often several repos — an engine, a customer repo, a UI, a model. Each has its own Permanence
stream, but a stakeholder wants **one** plan-and-status view across the whole thing. A group says "these
repos report into that folder", so finishing your day in *any* of them refreshes the shared trail.

The folder is written for someone **outside** the work — a programme manager or director who wants status
without taking the team's time to extract it. That audience sets the standard: every claim traces to a
commit, a file, or a measured output, because nobody who knows the ground truth checks it first.

## Rules

- **A project appears in exactly one group.** Resolution is an unambiguous longest-prefix lookup on cwd,
  exactly like `REGISTRY.md`. There is no "which group did you mean" case.
- **A group may have one member.** A single-project group is normal, not a degenerate case.
- **Any current member may write updates for the whole group.** A triggered member fills whatever gaps it
  can see and leaves the rest; the next trigger in any member fills more. The folder converges.
- **Reads of sibling repos are opportunistic, never required.** An unreachable member is recorded as
  unreachable — not silently skipped, and never a reason to fail the run. (Requiring every sibling couples
  the projects: it breaks when one isn't cloned, and makes one project report on work it can't see.)
- **Unregister by setting `left`, never by deleting the row.** A member that leaves keeps every entry it
  wrote; only the aggregate stops including it. Purging would make the trail untrue, and the trail is the
  point — the same reasoning as the people conventions: you don't delete someone's contributions when
  they move team.
- **Group names describe the programme**, not any one repo in it.
- **Progress is watermarked on a commit sha, not a date.** A date can't tell a 3pm run from commits that
  landed at 6pm, so same-day re-runs would silently miss work.

## Groups

Replace the example row. The **target repo** is where the shared folder lives; it is usually also a member
in its own right.

| group | target repo | programme folder | task doc |
|---|---|---|---|
| `example-programme` | /Users/you/path/to/the-customer-repo | `docs/programme/` | `docs/programme/UPDATING.md` |

## Membership

One row per repo that reports in. `role` is a short name for what that asset *is* — it's passed to the
task doc, which uses it to label entries. `joined` is that asset's own start point; `left` stays empty
while it's current.

| group | workspace path | role | joined | left |
|---|---|---|---|---|
| `example-programme` | /Users/you/path/to/the-engine | `engine` | 2026-01-15 | |
| `example-programme` | /Users/you/path/to/the-customer-repo | `manager` | 2026-01-15 | |
| `example-programme` | /Users/you/path/to/a-retired-asset | `prototype` | 2026-01-15 | 2026-03-02 |

A dormant member is a *status*, not a reason to unregister it — the report should say "hasn't reported
since <date>", which it can only do if the row is still there.

## Setting up the project side

Permanence holds only the pointer; the **procedure lives in the target repo** so that no project file ever
names Permanence. To create a group: add the rows above, then scaffold the task doc and the initial folder
into the target repo from `templates/programme-task-doc.md`.

The task doc receives `role` and the current `members` (with their local paths) as **inputs** from the
caller — it looks up no configuration of its own. That's what keeps the one-way pointer intact.
