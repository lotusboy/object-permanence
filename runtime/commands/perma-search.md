---
description: Semantic search across the whole Permanence — find notes by *meaning*, not keyword. Local ONNX embeddings (no API). Proposes where to look; you then read the real markdown. The additive "find" layer for cross-stream questions plain grep misses.
---

# Permanence — Semantic search

Use when you want "where have I noted anything *about* X?" across all streams and keyword-grep
would miss paraphrases/synonyms. For exact strings (a name, an ID, a path) prefer `grep`/`git` —
those stay the precise spine; this is the by-meaning layer on top.

1. **Run the query** (uses the local index; no API):
   `~/permanence/runtime/search/.venv/bin/python ~/permanence/runtime/search/perma-search.py query "<concept>" -k 8`
   Optionally scope: `--stream home/kitchen`.
2. **Read the hits.** The output is *where to look* — file + heading + a score. **Open the real
   markdown files for the top hits and read the actual sections** before answering. The index is a
   pointer, never the source of truth (propose-never-decide).
3. If results look stale (you know something's in there that didn't surface), **rebuild**:
   `~/permanence/runtime/search/.venv/bin/python ~/permanence/runtime/search/perma-search.py build`
   (rebuilds from current markdown; the index is disposable + gitignored).

**Setup (one-time, local, no API)** — needs Python ≥3.10, so use `uv` (system python may be older):
`uv venv ~/permanence/runtime/search/.venv --python 3.12 && uv pip install --python ~/permanence/runtime/search/.venv/bin/python -r ~/permanence/runtime/search/requirements.txt`
then build: `~/permanence/runtime/search/.venv/bin/python ~/permanence/runtime/search/perma-search.py build`.
(Tuning knobs: `--stream <name>` to scope, `--min 0.35` to drop weak hits.)

**Notes:** local ONNX embeddings — **default = MiniLM-L6** (chromadb's built-in; fetched from Chroma's
own S3, **not** Hugging Face, so it works HF-blocked, zero setup). Nothing leaves the machine. Index at
`runtime/search/.index/` (gitignored, rebuildable). The markdown is always the source of truth.

**Opting into a stronger embedder (e.g. bge-small):** set `PERMA_SEARCH_MODEL` to a fastembed name or
a **local model path**, then rebuild. Do this only after a **bake-off** shows it beats MiniLM on your
notes (build a second index, compare your real queries, keep the winner). Acquire bge **without HF**:
the **BAAI mirror** (`model.baai.ac.cn`) for the exact ONNX → place locally → `HF_HUB_OFFLINE=1` (note
fastembed reaches HF first); or **Ollama** for bge-m3 (its own registry). `.index/EMBEDDER` records what
built the index, so build/query stay consistent.
