# QUICKSTART

Five steps to a working Permanence. ~10 minutes.

## 1. Put it at `~/permanence`

From GitHub:

```bash
git clone https://github.com/lotusboy/object-permanence.git ~/permanence
cd ~/permanence && rm -rf .git && git init && git add -A && git commit -m "My Permanence"
```

Or, if you were handed a copy of the folder rather than the link:

```bash
cp -R <the-folder> ~/permanence
cd ~/permanence && rm -rf .git && git init && git add -A && git commit -m "My Permanence"
```

**Why the directory name changes.** The repo is called `object-permanence`; the install location is
always `~/permanence`, which every script assumes. That's why the clone command names its target
explicitly. (Override with `PERMA_DIR` only if you really need it elsewhere.)

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

## 2. Explore the example, then delete it

Open `~/permanence/example/` and read a stream or two (`home/bathroom`, `home/kitchen`) — that's the shape and the conventions in action. When it's clicked:

```bash
rm -rf ~/permanence/example     # your Permanence starts empty; the example was just the demo
```

## 3. Install the machinery

```bash
~/permanence/runtime/install.sh
```
This sets up **everything global, hands-off**: copies the `/perma-*` commands into Claude Code, arms the git hooks, loads the nightly consolidate, **and wires `~/.claude/settings.json`** (the SessionStart hook + the `~/permanence` permission) — merged in safely, leaving your other settings untouched. No manual editing. *(Only if you don't have `python3` will it print the settings snippet for you to paste instead.)*

## 4. Set the session's working folder — then register

**Do this before registering anything.** Each session has a *working folder* (the folder chip in the composer, next to the `Local`/environment chip). Set it to the project's own folder — that's what keeps sessions separate, and it's what Permanence resolves against. One session per project folder.

**Click the folder chip, not the "add another folder" button.** They do different things, and the difference is easy to get wrong: the chip *sets* the working folder; the plus button grants access to an **extra** folder while leaving the working folder as it was. **Permanence resolves the working folder only** — so if you leave it on your home folder and merely *add* the project, Permanence still resolves home and you get the wrong stream (or none). You never need to add `~/permanence` by hand, either: `install.sh` grants it globally, which is why Permanence reaches you from any project.

If you skip it, the session lands in your home folder, and registering *that* would make every home-defaulted session load a meaningless stream. Permanence now refuses to register a home/container folder and tells you to set the folder instead — but replacing `/Users/you` with your real home path in `_meta/REGISTRY.md`'s `perma-meta` row is still worth doing, so home sessions cleanly get brief-level access.

**Deleting a session is safe.** A session is just the conversation — deleting it leaves the folder, its files, your Permanence stream and the registry untouched. Point a new session at the same folder and it picks straight up. That's rather the point.

## 4b. Register your first project — just ask Claude

No file-wrangling. **Open the project itself in Claude Code** and just say:

> **"Register this project in Permanence"**  — and point it at the README if there is one: *"…here's the README: `<path>`"*

You don't need to tell it where Permanence is (always `~/permanence`) or run any command — from inside the project, Claude already knows to offer this. It reads the README, creates the stream seeded from it (PROJECT/LOG/QUESTIONS/PEOPLE), adds it to the registry, and confirms. No README? Just describe it ("set up a stream for doing up the bathroom") and it builds the stream from that.

That's it. **Next time you open that project, Permanence loads its context automatically.**

## 5. Then just use it

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

**Worth doing early — an encrypted off-machine backup (`runtime/make-backup.sh`).** Your Permanence is one git repository on one machine; if that machine is lost, so is everything in it, unless you've made your own copy. `runtime/make-backup.sh` bundles the whole history, encrypts it to a key only you hold, verifies the round-trip before trusting it, and keeps a few dated copies — the one-time setup and restore steps are in the comment at the top of the script itself. It checks your working tree before bundling and tells you plainly if anything's uncommitted (run `/perma-shutdown` first, or commit by hand, for a backup that covers everything). Not wired into `install.sh` — it's your call whether and how often to run it (a weekly cron/launchd entry alongside the nightly consolidate is a reasonable default once you've got real notes worth losing).

---

**The honest bit:** the real payoff is *your own* Permanence after a week or two, once it's holding state you'd otherwise lose. The example is just the bridge across the "empty Permanence, can't see the point yet" valley. Get one real stream going and let it accumulate.
