#!/usr/bin/env bash
# cogdebt-scan — a cognitive-debt scan for an AI-built repo.
# ---------------------------------------------------------------------------
# Why: per Anup Jadhav, "cognitive debt is the gap between what a system does and
# what the team understands about it" — and AI makes it worse (you supervise +
# reconstruct understanding AFTER, instead of building it WHILE typing). This turns
# his qualitative signals into git/grep proxies, tracks them over time, and — the
# point — EMITS A PERMANENCE EVENT when one crosses a line, so it surfaces loudly in
# whatever session you next open (the events bus), not buried in a log.
#
# 100% local: git + find + grep + python3 (stdlib only). NO model, NO API, NO network.
# Safe to run anytime (incl. during an Anthropic incident).
#
# Usage:  cogdebt-scan.sh [repo-path ...]      (default: the watch-list below)
#         cogdebt-scan.sh --quiet              (no stdout; just state + events — for cron)
#
# The PROXIES (and what each maps to in the article):
#   bus_factor_pct   % of commits by the single top author       → "drops to one or two who grasp it"
#   ai_authored_pct  % commits with a Co-Authored-By trailer      → supervise-not-author regime
#   biggest_file_loc largest source file (LOC)                    → complexity concentration / hard to hold
#   doc_to_code      doc-LOC / src-LOC                            → intent debt (the "why" captured?)
#   test_to_code     test-funcs / src-KLOC                        → anti-"surrender" (diffs must prove themselves)
#   unattended_14d   commits tagged autonomous/"steve out"/night, last 14 days, NOT yet
#                    followed by a human-review/refactor marker   → peak surrender risk: go read these
#
# Thresholds are deliberate + tunable. They flag STATE crossing a line AND TREND
# (got worse since last run, stored in .cogdebt-state.json). A solo asset sitting at
# bus_factor=100% is fine; a doc_to_code that DROPS, or a file that crosses BIG_FILE,
# or a run of unattended commits — those are the "go do something" signals.
set -uo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin"  # launchd has a minimal PATH

PERMA="${PERMA_DIR:-$HOME/permanence}"
STATE="$PERMA/_meta/.cogdebt-state.json"          # gitignored: prior run, for trend deltas
REPORT_DIR="$PERMA/_meta/cogdebt"                  # dated reports (gitignored runtime output)
QUIET=0; REPOS=()
for a in "$@"; do [ "$a" = "--quiet" ] && QUIET=1 || REPOS+=("$a"); done
# Default watch-list: the AI-built assets worth watching. Edit here to add repos.
PLACEHOLDER="$HOME/path/to/your/ai-built-repo"
[ ${#REPOS[@]} -eq 0 ] && REPOS=("$PLACEHOLDER")

# Unconfigured: refuse to run rather than silently misreport. Left running against the
# placeholder, this either logged "not a git repo" every week forever, or — if something
# genuinely existed at that literal path but wasn't Python — measured src_loc=0, tripped both
# the doc_to_code and test_per_kloc floors, and emitted FALSE cognitive-debt breach events into
# every open session. Both are worse than simply saying "not configured yet."
if [ "${#REPOS[@]}" -eq 1 ] && [ "${REPOS[0]}" = "$PLACEHOLDER" ]; then
  [ "$QUIET" -eq 1 ] || echo "cogdebt-scan: not configured — edit the REPOS watch-list at the top of this script (or pass repo paths as arguments) before it has anything to measure."
  exit 0
fi

# --- tunable thresholds ---
BIG_FILE=1000        # a single source file over this many LOC = concentration flag
DOC_CODE_MIN=0.50    # doc-LOC should be >= this * src-LOC (intent capture floor)
TEST_KLOC_MIN=15     # >= this many test functions per 1000 src LOC (anti-surrender floor)
UNATTENDED_MAX=8     # more than this many unreviewed autonomous commits in 14d = go-read flag

metrics_json() {  # gather raw numbers for ONE repo → JSON line
  local R="$1"; [ -d "$R/.git" ] || { echo "{\"repo\":\"$R\",\"error\":\"not a git repo\"}"; return; }
  local src testfuncs doc big bigf commits topauthor topn ai unatt
  src=$(git -C "$R" ls-files '*.py' | grep -viE '/tests?/|test_|_test')
  local srcloc; srcloc=$(printf '%s\n' "$src" | sed '/^$/d' | xargs -I{} wc -l "$R/{}" 2>/dev/null | awk '{s+=$1} END{print s+0}')
  testfuncs=$(git -C "$R" grep -hE '^[[:space:]]*def test_' -- '*.py' 2>/dev/null | wc -l | tr -d ' ')
  doc=$(git -C "$R" ls-files '*.md' | sed '/^$/d' | xargs -I{} wc -l "$R/{}" 2>/dev/null | awk '{s+=$1} END{print s+0}')
  read -r big bigf < <(printf '%s\n' "$src" | sed '/^$/d' | xargs -I{} wc -l "$R/{}" 2>/dev/null | sort -rn | awk 'NR==1{print $1" "$2}')
  commits=$(git -C "$R" rev-list --count HEAD)
  topn=$(git -C "$R" shortlog -sn HEAD | head -1 | awk '{print $1}')
  topauthor=$(git -C "$R" shortlog -sn HEAD | head -1 | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//')
  ai=$(git -C "$R" log --format='%b' | grep -ci 'Co-Authored-By')
  unatt=$(git -C "$R" log --since='14 days ago' --oneline | grep -ciE 'autonomous|no spend|offline session|steve out|night[0-9]?\b')
  python3 - "$R" "$srcloc" "$testfuncs" "$doc" "$big" "$bigf" "$commits" "$topn" "$ai" "$unatt" "$topauthor" <<'PY'
import json,sys
R,srcloc,tf,doc,big,bigf,commits,topn,ai,unatt,topauthor=sys.argv[1:12]
srcloc,tf,doc,big,commits,topn,ai,unatt=(int(x) for x in (srcloc,tf,doc,big,commits,topn,ai,unatt))
print(json.dumps({"repo":R,"src_loc":srcloc,"test_funcs":tf,"doc_loc":doc,
  "biggest_file_loc":big,"biggest_file":bigf,"commits":commits,
  "bus_factor_pct":round(100*topn/commits) if commits else 0,"top_author":topauthor,
  "ai_authored_pct":round(100*ai/commits) if commits else 0,"unattended_14d":unatt,
  "doc_to_code":round(doc/srcloc,2) if srcloc else 0,
  "test_per_kloc":round(1000*tf/srcloc,1) if srcloc else 0}))
PY
}

mkdir -p "$REPORT_DIR"
ALL="["; first=1
for R in "${REPOS[@]}"; do
  m=$(metrics_json "$R"); [ $first -eq 1 ] && first=0 || ALL+=","; ALL+="$m"
done
ALL+="]"

# Compute breaches + trend deltas vs last run, render report, decide events — in python.
# $ALL is passed as a real argv string, parsed with json.loads — NOT embedded as literal Python
# source inside the heredoc (the old '''$ALL''' form). A repo's commit author name (`topauthor`,
# gathered from `git shortlog`) flows into $ALL uninspected; embedded as source text, a name
# containing the sequence that closes a Python triple-quoted string would have let arbitrary
# Python run inside this scheduled, unattended job. json.loads only ever parses data, never executes it.
python3 - "$STATE" "$REPORT_DIR" "$QUIET" "$PERMA" "$BIG_FILE" "$DOC_CODE_MIN" "$TEST_KLOC_MIN" "$UNATTENDED_MAX" "$ALL" <<'PY'
import json,sys,os,subprocess,datetime
state_f,report_dir,quiet,perma,BIG,DOCMIN,TESTMIN,UNATT,all_json=sys.argv[1:10]
quiet=quiet=="1"; BIG=int(BIG); DOCMIN=float(DOCMIN); TESTMIN=float(TESTMIN); UNATT=int(UNATT)
cur=json.loads(all_json)
prior={}
try:
    for r in json.load(open(state_f)): prior[r["repo"]]=r
except Exception: pass

lines=[]; breaches=[]
for m in cur:
    if m.get("error"): lines.append(f"{m['repo']}: {m['error']}"); continue
    p=prior.get(m["repo"],{})
    def d(k):  # trend arrow vs last run
        if k not in p: return ""
        delta=round(m[k]-p[k],2)
        return f"  (was {p[k]}, {'+' if delta>=0 else ''}{delta})" if delta else "  (unchanged)"
    name=os.path.basename(m["repo"].rstrip("/"))
    lines += [f"\n## {name}",
      f"  bus_factor:     {m['bus_factor_pct']}% ({m['top_author']}){d('bus_factor_pct')}",
      f"  ai_authored:    {m['ai_authored_pct']}%{d('ai_authored_pct')}",
      f"  src/doc/test:   {m['src_loc']} src-LOC · {m['doc_loc']} doc-LOC · {m['test_funcs']} tests",
      f"  doc_to_code:    {m['doc_to_code']}  (floor {DOCMIN}){d('doc_to_code')}",
      f"  test_per_kloc:  {m['test_per_kloc']}  (floor {TESTMIN}){d('test_per_kloc')}",
      f"  biggest_file:   {m['biggest_file_loc']} LOC — {os.path.basename(m['biggest_file']) if m['biggest_file'] else '?'}  (cap {BIG}){d('biggest_file_loc')}",
      f"  unattended_14d: {m['unattended_14d']}  (cap {UNATT}){d('unattended_14d')}"]
    # breach rules — state crossing a line OR trend worsening
    if m["doc_to_code"] < DOCMIN: breaches.append(f"{name}: intent debt — doc/code {m['doc_to_code']} < {DOCMIN} (the 'why' is thinning)")
    elif "doc_to_code" in p and m["doc_to_code"] < p["doc_to_code"]-0.1: breaches.append(f"{name}: doc/code dropped {p['doc_to_code']}→{m['doc_to_code']} (why-capture slipping)")
    if m["test_per_kloc"] < TESTMIN: breaches.append(f"{name}: surrender risk — only {m['test_per_kloc']} tests/kLOC < {TESTMIN}")
    if m["biggest_file_loc"] > BIG: breaches.append(f"{name}: {os.path.basename(m['biggest_file'])} is {m['biggest_file_loc']} LOC (>{BIG}) — hard to hold; consider splitting")
    if m["unattended_14d"] > UNATT: breaches.append(f"{name}: {m['unattended_14d']} unreviewed autonomous commits in 14d (>{UNATT}) — read them + confirm you can defend them")

stamp=datetime.datetime.utcnow().strftime("%Y-%m-%d-%H%M")
report=f"# Cognitive-debt scan {stamp}\n"+"\n".join(lines)
report+="\n\n## Flags\n"+("\n".join(f"- ⚠️ {b}" for b in breaches) if breaches else "- none — within thresholds")
open(os.path.join(report_dir,f"REPORT-{stamp}.md"),"w").write(report)
json.dump(cur,open(state_f,"w"),indent=2)  # new baseline
if not quiet: print(report)

# LOUD reminder: emit a Permanence event per scan-with-breaches (source 'cogdebt' → all sessions see it)
if breaches:
    msg="Cognitive-debt scan flagged "+str(len(breaches))+": "+" | ".join(breaches)+f". Full report: _meta/cogdebt/REPORT-{stamp}.md"
    emit=os.path.join(perma,"runtime","emit-event.sh")
    if os.access(emit,os.X_OK):
        subprocess.run([emit,"all",msg],env={**os.environ,"PERMA_EMIT_SOURCE":"cogdebt"},
                       stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    if not quiet: print(f"\n>>> emitted {len(breaches)} cognitive-debt event(s) to open sessions.")
PY
