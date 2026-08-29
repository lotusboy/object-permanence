# REGISTRY — workspace → Permanence stream

> The machine-read map linking each project folder on your machine to Permanence stream it should load. Parsed by `runtime/session-start.sh` (longest-prefix match on the current directory). **The pointer goes one way: this file (in Permanence) references your projects — never the reverse.**
>
> Add one row per project folder you want Permanence to recognise. Unregistered folders get brief-level access only, plus a one-time offer to register. The special stream value `perma-meta` means "no project stream — brief-level only".

| workspace path | stream | notes |
|---|---|---|
| /Users/you/path/to/a-project | home/a-project | example row — replace with your own |
| /Users/you | perma-meta | home / non-project sessions — brief-level only |

Ordering note: put more-specific paths above shorter prefixes of themselves (the parser takes the longest match).
