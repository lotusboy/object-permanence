# QUICKSTART

Six steps to a working Permanence. ~10 minutes.

## 1. Put it at `~/permanence`

From GitHub:

```bash
git clone https://github.com/lotusboy/permanence.git ~/permanence
cd ~/permanence && rm -rf .git && git init && git add -A && git commit -m "My Permanence"
```

Or, if you were handed a copy of the folder rather than the link:

```bash
cp -R <the-folder> ~/permanence
cd ~/permanence && rm -rf .git && git init && git add -A && git commit -m "My Permanence"
```

**The install location is always `~/permanence`** — every script assumes it. (Override with
`PERMA_DIR` only if you genuinely need it elsewhere.)

**Why `.git` gets thrown away.** Your Permanence fills with private notes about real projects and real
people, so it becomes *your* repository with *your* history — not a fork of the template, and never
something you'd push back upstream. The initial commit matters too: it's what arms the git hooks and
lets the install stamp a version on the commands. You can still pull future template improvements —
`/perma-upgrade` reads the upstream URL from `runtime/.update-source`, a tracked file, not from the git
remote you just removed.

> **Platform notes.** Works on macOS and Linux with no changes. On **Windows**, use Claude Code with
> **Git for Windows** installed (it bundles Git Bash, which Claude Code uses to run these scripts
> automatically) — `~/permanence` resolves correctly under Git Bash the same way it does on macOS/Linux.
> If your Windows profile is redirected into a OneDrive-synced folder, consider moving `~/permanence`
> somewhere not continuously cloud-synced — a git repo and a sync client both wanting to touch the same
> files can cause odd behavior.

## 2. Back up before you forget

**This is the point where it matters most, so it's worth doing now rather than "eventually."** The
`.git` history you just created is local-only — there's no remote, and nothing here sets one up.
`runtime/make-backup.sh` gives you an encrypted, verified off-machine backup in one command: it bundles
the whole history, encrypts it to a key only you hold, verifies the round-trip before trusting it, and
keeps a few dated copies. The one-time setup and restore steps are in the comment at the top of the
script itself.

```bash
age-keygen -o ~/.config/age/perma-backup.key    # one-time — store this key safely, separately from the backup
~/permanence/runtime/make-backup.sh
```

It's **not** run automatically — `install.sh` doesn't schedule it, and it checks your working tree
before bundling, telling you plainly if anything's uncommitted (run `/perma-shutdown` first, or commit
by hand, for a backup that covers everything). Re-run it any time; a weekly cron/launchd entry alongside
the nightly consolidate is a reasonable default once you've got real notes worth losing. If this machine
is the only copy and something happens to it, losing the machine loses everything — this script is the
whole difference.

## 3. Explore the example, then delete it

Open `~/permanence/example/` and read a stream or two (`home/bathroom`, `home/kitchen`) — that's the shape and the conventions in action. When it's clicked:

```bash
rm -rf ~/permanence/example     # your Permanence starts empty; the example was just the demo
```

## 4. Install the machinery

```bash
~/permanence/runtime/install.sh
```
This sets up **everything global, hands-off**: copies the `/perma-*` commands into Claude Code, arms the git hooks, loads the nightly consolidate, **and wires `~/.claude/settings.json`** (the SessionStart hook + the `~/permanence` permission) — merged in safely, leaving your other settings untouched. No manual editing. *(Only if you don't have `python3` will it print the settings snippet for you to paste instead.)*

## 5. Register your first project

How this works depends on what you're using — pick the one that matches you:

**Using Claude Code, via VS Code or the CLI (probably you, if you're a software engineer).** Your
working directory already *is* your project — open the project as your VS Code workspace, or `cd` into
it before running `claude`. No extra step needed: just open the project and say **"register this
project"**.

**Using a desktop app with local file access (Claude Desktop, ChatGPT Desktop, or similar).** Don't rely
on the app's own folder/workspace concept — it varies by app, and Permanence doesn't know about it
either way. If there's a real folder for this project, just say its path: **"register this project at
`/Users/you/path/to/it`"**. That works identically no matter how the app itself scopes file access. If
there's no folder at all — a topic you just want to think out loud about — a name is enough: **"start a
new project called kitchen renovation"**. No path, no folder to think about; Permanence picks a real
folder for you (under `~/Permanence Projects/`) and tells you where, in case you ever want it.

**Either way**, from there it's the same:

> **"Register this project in Permanence"** — and point it at the README if there is one: *"…here's the README: `<path>`"* (or the explicit path, if you're using a desktop app per above).

You don't need to tell it where Permanence is (always `~/permanence`) or run any command — Claude already knows to offer this. It reads the README, creates the stream seeded from it (PROJECT/LOG/QUESTIONS/PEOPLE), adds it to the registry, and confirms. No README? Just describe it ("set up a stream for doing up the bathroom") and it builds the stream from that.

That's it. **Next time you open that project, Permanence loads its context automatically.**

A couple of things worth knowing:

- **If you skip setting a real project path, the session lands in your home folder**, and registering *that* would make every home-defaulted session load a meaningless stream. Permanence now refuses to register a home/container folder and tells you to set the folder instead — but replacing `/Users/you` with your real home path in `_meta/REGISTRY.md`'s `perma-meta` row is still worth doing, so home sessions cleanly get brief-level access.
- **Deleting a session is safe.** A session is just the conversation — deleting it leaves the folder, its files, your Permanence stream and the registry untouched. Point a new session at the same folder and it picks straight up. That's rather the point.
- **A project isn't tied to one app.** Once it's registered, the same project is reachable both ways — open its folder in VS Code, or just say its name in a desktop app — it's the same stream either way, no extra setup per app.
- **Desktop-app users: `/perma-startup` and `/perma-shutdown` take a project name *or* a path** — say *"good morning Permanence, kitchen renovation"* or give the folder path, whichever you remember, instead of relying on the app's folder to pick the project for you. Not sure of the exact name? Ask to **"list my Permanence projects"** first (`/perma-list`). Switching projects mid-conversation is just calling it again with a different name — Permanence will check first if the one you're leaving still has anything worth winding down.

## 6. Then just use it

**Talk to Claude about the project as you work** — it keeps the stream updated. Run `/perma-brief` of a morning for the across-everything picture; `/perma-consolidate` occasionally to tidy. Ignore `/perma-orchestrate` until you've got a few streams.

**`/perma-help` any time you've forgotten what's available** — it lists every command and shows which background pieces are actually switched on for *your* machine, so you're never guessing.

**A daily pair worth trying early:** `/perma-shutdown` when you stop (it gets the day's open loops out of your head and into the stream, with exact resume points), and `/perma-startup` when you start (where you left off, plus a couple of candidates for what's next). They're the two that make Permanence feel like it's carrying something for you rather than being another thing to maintain.

**The nightly tidy needs a token.** `install.sh` schedules a nightly consolidate (05:30) that runs Claude unattended. Scheduled jobs get no shell config, so it can't see your normal login — give it a token of its own:

```bash
claude setup-token                       # prints a token
mkdir -p ~/.config/perma
echo 'export CLAUDE_CODE_OAUTH_TOKEN=<paste-it-here>' > ~/.config/perma/claude-code-oauth-token.env
chmod 600 ~/.config/perma/claude-code-oauth-token.env
```

Keep it in that file rather than your shell profile — in your profile it can leak into other tools and override your normal Claude Code login. Already keep it somewhere else? Set `PERMA_TOKEN_ENV` to that path instead. Skip this and the nightly run simply aborts each night with a message telling you the same thing — it will **never** fall back to an API key.

**Optional — cross-project events.** Once you've got two or more projects you switch between, you can let one quietly tell the others when something material happens (`/perma-emit`), so the Claude in your other open project picks it up next time you type there. *Emitting* works out of the box; *receiving* is opt-in — `install.sh` prints the one `settings.json` hook line to enable it (it runs on every prompt, so it's left for you to switch on deliberately). Skip this until you actually feel the "I changed X over here and forgot to tell the other project" pain.

**Optional — programme groups (one report across several repos).** For **one owner** spanning several of their own repos — if one programme spans more than one repo and somebody outside the work keeps asking where things are, `/perma-register-group` sets up a shared plan-and-status folder in the coordinating repo. (Not for coordinating different people on different laptops — see the README for why.) After that, a `/perma-shutdown` in *any* member repo refreshes the whole folder — it converges, so you never have to be in the "right" repo. It's written for a reader who can't check it, so every claim traces to a commit or a measured output, and the RAG rules are fixed so several programmes can be scanned side by side. Skip it entirely if you've one repo per programme.

**Optional — semantic search (`/perma-search`).** Once you've got a fair bit of accumulated notes, grep-by-keyword starts missing things you remember by *meaning*. `/perma-search "some concept"` finds them — local embeddings, nothing leaves the machine, and it only *points* you at the files (you still read the real markdown). One-time setup builds a small local index (`install.sh` prints the command); after that the post-commit hook keeps it fresh. Like events, skip it until plain grep starts failing you.

---

**The honest bit:** the real payoff is *your own* Permanence after a week or two, once it's holding state you'd otherwise lose. The example is just the bridge across the "empty Permanence, can't see the point yet" valley. Get one real stream going and let it accumulate.
