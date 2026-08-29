#!/usr/bin/env python3
"""perma-search — local semantic search over Permanence's markdown.

A standard local-RAG pattern: a local ChromaDB index over heading-aware markdown chunks.
Embeddings are 100% on-CPU, ZERO API, no torch.

Embedding model (the quality lever, orthogonal to the store):
  default = MiniLM-L6 (chromadb's built-in ONNX embedder) — proven, and fetched from Chroma's own
  S3, NOT Hugging Face, so it works even in HF-blocked environments. Zero extra setup.
  Opt into a stronger model (e.g. bge-small-en-v1.5) by setting PERMA_SEARCH_MODEL to a fastembed
  model name OR a local model path. CAVEAT: fastembed downloads from Hugging Face first — so in an
  HF-blocked env, acquire bge from the BAAI mirror (model.baai.ac.cn) / Ollama / your artifact store,
  place it locally, and point PERMA_SEARCH_MODEL at that path (HF_HUB_OFFLINE=1). Adopt bge only after
  a measured bake-off shows it beats MiniLM on your own notes. .index/EMBEDDER records what built it.

Discipline: PROPOSE, never decide. A query returns *where to
look* (file + heading + score); the caller reads the real curated markdown for the hits.
Deterministic grep/git stays the precise spine — this is the additive "find by meaning" layer.

Usage:
    perma-search.py build                  # (re)build the whole index
    perma-search.py update <file.md>...    # incrementally re-index changed files (post-commit hook)
    perma-search.py query "some concept"   # top-k semantic hits across all streams
    perma-search.py query "..." -k 8 --stream home/kitchen --min 0.35

Setup (one-time, local, no API) — needs Python >=3.10; use uv (system python may be older):
    uv venv ~/permanence/runtime/search/.venv --python 3.12
    uv pip install --python ~/permanence/runtime/search/.venv/bin/python -r ~/permanence/runtime/search/requirements.txt
"""
import argparse, os, re, sys, hashlib

PERMA = os.environ.get("PERMA_DIR", os.path.expanduser("~/permanence"))
INDEX_DIR = os.path.join(PERMA, "runtime", "search", ".index")
COLLECTION = "permanence"
MODEL = os.environ.get("PERMA_SEARCH_MODEL", "")  # "" = MiniLM (chromadb default; no HF). Set to a
                                                  # fastembed name or LOCAL path to opt into e.g. bge.
SKIP_DIRS = {".git", ".consolidation", ".index", ".venv", "node_modules", ".events-seen"}
MAX_CHUNK = 1800
_CACHE = {}


def iter_md(root):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fn in filenames:
            if fn.endswith(".md"):
                yield os.path.join(dirpath, fn)


def stream_of(abspath):
    """A stream = the dir that owns a PROJECT.md on this file's path (Permanence's own
    definition) — works for any layout, no hardcoded names. Falls back to top-level dir."""
    perma_root = os.path.abspath(PERMA)
    cur, best = os.path.dirname(os.path.abspath(abspath)), None
    while cur.startswith(perma_root):
        if os.path.exists(os.path.join(cur, "PROJECT.md")):
            best = cur
        if cur == perma_root:
            break
        cur = os.path.dirname(cur)
    if best and best != perma_root:
        return os.path.relpath(best, PERMA)
    parts = os.path.relpath(os.path.abspath(abspath), PERMA).split(os.sep)
    return parts[0] if len(parts) > 1 else "(root)"


def useful(body):
    """Drop low-value chunks: trivial one-liners + transcript cue-boilerplate (VTT timestamp
    lines with little prose). Keeps substantive spoken passages."""
    prose = "\n".join(l for l in body.splitlines()
                      if not re.match(r"^\s*\d{1,2}:\d{2}:\d{2}", l) and "-->" not in l)
    return len(re.sub(r"\s+", " ", prose).strip()) >= 40


def chunk_md(text):
    """Section-aware: split on markdown headings; long sections split on blank lines."""
    lines = text.splitlines()
    sections, cur_head, cur = [], "(top)", []
    for ln in lines:
        if re.match(r"^#{1,6}\s", ln):
            if cur:
                sections.append((cur_head, "\n".join(cur).strip()))
            cur_head, cur = ln.lstrip("# ").strip(), [ln]
        else:
            cur.append(ln)
    if cur:
        sections.append((cur_head, "\n".join(cur).strip()))
    out = []
    for head, body in sections:
        if not body:
            continue
        if len(body) <= MAX_CHUNK:
            out.append((head, body))
        else:
            buf = ""
            for para in body.split("\n\n"):
                if len(buf) + len(para) > MAX_CHUNK and buf:
                    out.append((head, buf.strip())); buf = ""
                buf += para + "\n\n"
            if buf.strip():
                out.append((head, buf.strip()))
    return out


def _chunks_for(abspath, rel):
    docs, metas, ids = [], [], []
    try:
        text = open(abspath, encoding="utf-8").read()
    except Exception:
        return docs, metas, ids
    for i, (head, body) in enumerate(chunk_md(text)):
        if not useful(body):
            continue
        docs.append(f"{head}\n{body}")
        metas.append({"file": rel, "stream": stream_of(abspath), "heading": head})
        ids.append(hashlib.sha1(f"{rel}#{i}".encode()).hexdigest())
    return docs, metas, ids


# --- embedding (the quality lever): bge-small via fastembed, MiniLM fallback ---
def _embed(texts):
    """Embed via the opt-in model (PERMA_SEARCH_MODEL), or return None to use chromadb's default
    MiniLM. None when: no model set (the default), or the model can't load. Local ONNX; no API.
    NB fastembed reaches Hugging Face first — for bge in an HF-blocked env, set PERMA_SEARCH_MODEL to
    a LOCAL path (from the BAAI mirror) and HF_HUB_OFFLINE=1."""
    if not MODEL or MODEL.lower() in ("minilm", "minilm-l6", "default"):
        return None  # → chromadb's built-in MiniLM (no fetch, no HF)
    if "m" not in _CACHE:
        try:
            from fastembed import TextEmbedding
            _CACHE["m"] = TextEmbedding(model_name=MODEL)
        except Exception:
            _CACHE["m"] = None
    m = _CACHE["m"]
    if m is None:
        return None
    return [list(map(float, v)) for v in m.embed(list(texts))]


def _mode_file():
    return os.path.join(INDEX_DIR, "EMBEDDER")


def _read_mode():
    try:
        return open(_mode_file()).read().strip()
    except Exception:
        return "default"


def get_collection(reset=False):
    import chromadb
    client = chromadb.PersistentClient(path=INDEX_DIR)
    if reset:
        try:
            client.delete_collection(COLLECTION)
        except Exception:
            pass
    # cosine space; chromadb's default EF (ONNX MiniLM) is the fallback when we don't pass vectors.
    return client.get_or_create_collection(COLLECTION, metadata={"hnsw:space": "cosine"})


def _add(col, docs, metas, ids, vecs):
    B = 500
    for s in range(0, len(docs), B):
        if vecs is not None:
            col.add(documents=docs[s:s+B], embeddings=vecs[s:s+B],
                    metadatas=metas[s:s+B], ids=ids[s:s+B])
        else:
            col.add(documents=docs[s:s+B], metadatas=metas[s:s+B], ids=ids[s:s+B])


def build():
    os.makedirs(INDEX_DIR, exist_ok=True)
    col = get_collection(reset=True)
    docs, metas, ids, nfiles = [], [], [], 0
    for path in iter_md(PERMA):
        rel = os.path.relpath(path, PERMA)
        d, m, i = _chunks_for(path, rel)
        if d:
            nfiles += 1; docs += d; metas += m; ids += i
    vecs = _embed(docs)
    mode = f"vectors:{MODEL}" if vecs is not None else "default(minilm)"
    open(_mode_file(), "w").write(mode)
    _add(col, docs, metas, ids, vecs)
    print(f"indexed {len(docs)} chunks from {nfiles} files  [{mode}]  → {INDEX_DIR}")
    if vecs is None and MODEL and MODEL.lower() not in ("minilm", "minilm-l6", "default"):
        print(f"  note: requested model '{MODEL}' didn't load — used chromadb's MiniLM so search "
              f"works. Place the model locally (e.g. from the BAAI mirror) + set HF_HUB_OFFLINE=1, "
              f"or fix the path, then re-`build`. (fastembed reaches Hugging Face first.)")


def update(paths):
    if not os.path.isdir(INDEX_DIR):
        return
    col = get_collection()
    use_vectors = _read_mode().startswith("vectors")
    n = 0
    for p in paths:
        ap = os.path.abspath(p); rel = os.path.relpath(ap, PERMA)
        if rel.startswith("..") or any(part in SKIP_DIRS for part in rel.split(os.sep)):
            continue
        try:
            col.delete(where={"file": rel})
        except Exception:
            pass
        if os.path.exists(ap) and ap.endswith(".md"):
            d, m, i = _chunks_for(ap, rel)
            if d:
                vecs = _embed(d) if use_vectors else None
                _add(col, d, m, i, vecs)
        n += 1
    print(f"index updated for {n} file(s)  [{_read_mode()}]")


def query(q, k, stream, min_sim):
    col = get_collection()
    where = {"stream": stream} if stream else None
    vectors_mode = _read_mode().startswith("vectors")
    qv = _embed([q]) if vectors_mode else None
    if vectors_mode and qv is None:
        print("⚠️  index was built with a custom embedder that isn't loading now — results would be "
              "wrong. Set PERMA_SEARCH_MODEL to the same model (or rebuild on MiniLM).", file=sys.stderr)
        return
    if qv is not None:
        res = col.query(query_embeddings=qv, n_results=k, where=where)
    else:
        res = col.query(query_texts=[q], n_results=k, where=where)
    metas = res["metadatas"][0]; dists = res["distances"][0]
    hits = [(1 - d, m) for m, d in zip(metas, dists) if (1 - d) >= min_sim]
    if not hits:
        print(f"(no hits ≥ {min_sim:.2f} — broaden the query, lower --min, or rebuild)"); return
    print(f'top {len(hits)} for: "{q}"' + (f"  [stream={stream}]" if stream else "")
          + (f"  [min {min_sim:.2f}]" if min_sim else ""))
    for sim, m in hits:
        tag = "" if sim >= 0.30 else "  (weak)"
        print(f"\n  • {sim:.2f}{tag}  {m['file']}  ·  {m['heading']}")
    print("\n(Propose-only: open the files above and read the real sections before relying on this.)")


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("build")
    up = sub.add_parser("update"); up.add_argument("paths", nargs="+")
    qp = sub.add_parser("query")
    qp.add_argument("q")
    qp.add_argument("-k", type=int, default=6)
    qp.add_argument("--stream", default=None)
    qp.add_argument("--min", type=float, default=0.0, dest="min_sim",
                    help="hide hits below this cosine similarity (0..1); 0 = show all top-k")
    a = ap.parse_args()
    try:
        import chromadb  # noqa
    except ImportError:
        sys.exit("chromadb not installed. One-time: uv venv runtime/search/.venv --python 3.12 && "
                 "uv pip install --python runtime/search/.venv/bin/python -r runtime/search/requirements.txt")
    if a.cmd == "build":
        build()
    elif a.cmd == "update":
        update(a.paths)
    else:
        query(a.q, a.k, a.stream, a.min_sim)


if __name__ == "__main__":
    main()
