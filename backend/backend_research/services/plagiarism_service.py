"""
Plagiarism service: AI similarity analysis, paraphrase/humanize, citation, DB CRUD.
Uses the multi-model fallback chain from ai_service to survive per-model quota errors.
"""

import json
import re
from typing import List, Optional
from uuid import UUID

import numpy as np
from sqlalchemy.orm import Session
from sqlalchemy import desc

from models import PlagiarismCheck

# Gemini helper — goes through the fallback chain
async def _ask_gemini(prompt: str, json_mode: bool = False) -> str:
    from services.ai_service import _generate_with_fallback
    return await _generate_with_fallback(prompt, json_mode=json_mode)


def _split_sentences(text: str) -> List[str]:
    # Simple, robust sentence splitter
    text = re.sub(r'\s+', ' ', text.strip())
    parts = re.split(r'(?<=[.!?])\s+', text)
    return [p.strip() for p in parts if len(p.strip()) > 15]


def _cosine(a, b):
    a = np.asarray(a, dtype=np.float32)
    b = np.asarray(b, dtype=np.float32)
    denom = (np.linalg.norm(a) * np.linalg.norm(b)) or 1e-9
    return float(np.dot(a, b) / denom)


async def analyze_text(text: str) -> dict:
    """
    Real plagiarism detection using embeddings against Semantic Scholar.
    """
    from services.ai_service import build_search_query
    from services.search_service import search_semantic_scholar
    from services.embedding_service import embed_texts

    # ---- 1. Sentences ----
    sentences = _split_sentences(text)
    if not sentences:
        return {"similarity_score": "0%", "matches": []}

    # ---- 2. Keywords (LLM, 1 call) ----
    keywords_data = await build_search_query(text[:1500])
    if keywords_data and keywords_data.get("boolean_query"):
        query = keywords_data["boolean_query"]
    elif keywords_data and keywords_data.get("keywords"):
        query = " ".join(keywords_data["keywords"][:4])
    else:
        query = " ".join(sentences[0].split()[:8])

    # ---- 3. Corpus from Semantic Scholar ----
    try:
        papers = await search_semantic_scholar(query=query, limit=20)
    except Exception as e:
        print(f"[Plagiarism] S2 fetch failed: {e}")
        papers = []

    # Filter out papers without an abstract
    papers = [p for p in papers if p.get("abstract") and len(p["abstract"]) > 100]

    if not papers:
        return {
            "similarity_score": "0%",
            "matches": [],
            "note": "No comparable papers found in Semantic Scholar.",
        }

    # ---- 4. Embed everything in two batches ----
    sentence_vecs = embed_texts(sentences)
    abstract_vecs = embed_texts([p["abstract"] for p in papers])

    # ---- 5. Compare ----
    matches = []
    flagged_sentence_indices = set()
    THRESHOLD = 0.75

    for i, s_vec in enumerate(sentence_vecs):
        best_score = 0.0
        best_paper = None
        for j, a_vec in enumerate(abstract_vecs):
            score = _cosine(s_vec, a_vec)
            if score > best_score:
                best_score = score
                best_paper = papers[j]

        if best_score >= THRESHOLD and best_paper is not None:
            flagged_sentence_indices.add(i)
            matches.append({
                "id": len(matches) + 1,
                "text": sentences[i],
                "percentage": f"{int(best_score * 100)}%",
                "words": len(sentences[i].split()),
                "source": best_paper.get("title") or "Unknown source",
                "authors": best_paper.get("authors") or "",
                "year": str(best_paper.get("year") or "n.d."),
                "url": best_paper.get("url") or "",
                "excerpt": (best_paper.get("abstract") or "")[:200],
            })

    # ---- 6. Overall score ----
    total = len(sentences)
    flagged = len(flagged_sentence_indices)
    score_pct = int(round((flagged / total) * 100)) if total else 0

    return {
        "similarity_score": f"{score_pct}%",
        "matches": matches,
    }


# Paraphrase / Humanize
_PROMPTS = {
    "paraphrase": """You are an academic writing assistant. Paraphrase the text below
to reduce plagiarism while preserving meaning. Use different vocabulary and
sentence structure. Keep it academic and formal. Return ONLY the rewritten text —
no explanations, no quotes.

TEXT:
{text}

PARAPHRASED:""",

    "humanize": """You are an academic writing assistant. Rewrite the text below
to sound more natural, human, and less AI-generated. Use varied sentence lengths
and natural transitions. Preserve the original meaning. Return ONLY the rewritten
text — no explanations.

TEXT:
{text}

HUMANIZED:""",
}


async def rewrite_text(text: str, mode: str) -> str:
    if mode not in _PROMPTS:
        raise ValueError(f"Invalid mode: {mode}")
    prompt = _PROMPTS[mode].format(text=text)
    return (await _ask_gemini(prompt)).strip()


def format_citation(source: str, year: str = "2023", style: str = "APA 7") -> str:
    source = (source or "").strip()
    year = (year or "n.d.").strip()
    if not source:
        return ""

    # Case 1: single author "Ganeju, S."
    m = re.match(r"^([A-Z][A-Za-z'\-]+),\s*[A-Z]\.", source)
    if m and source.count(",") == 1:
        return f"({m.group(1)}, {year})"

    # Case 2: multi-author "Ganeju, S., Subedi, A., ..."
    m = re.match(r"^([A-Z][A-Za-z'\-]+),", source)
    if m:
        return f"({m.group(1)} et al., {year})"

    # Case 3: title — skip stopwords, take first meaningful word
    stopwords = {"a", "an", "the", "of", "in", "on", "for", "and", "or",
                 "to", "at", "by", "with", "is", "are", "be", "using",
                 "based", "designing", "towards", "toward", "from",
                 "into", "over", "under"}
    for w in re.findall(r"[A-Za-z][A-Za-z'\-]+", source):
        if w.lower() not in stopwords and len(w) > 2:
            return f"({w}, {year})"

    return f"({source}, {year})"


# DB CRUD
def save_check(
    db: Session,
    text: str,
    similarity_score: str,
    matches: List[dict],
    user_id: Optional[str] = None,
) -> PlagiarismCheck:
    row = PlagiarismCheck(
        document_text=text,
        similarity_score=str(similarity_score),
        matches=matches,
        user_id=user_id,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def list_checks(db: Session, user_id: Optional[str] = None) -> List[PlagiarismCheck]:
    q = db.query(PlagiarismCheck)
    if user_id:
        q = q.filter(PlagiarismCheck.user_id == user_id)
    return q.order_by(desc(PlagiarismCheck.created_at)).all()


def get_check(db: Session, check_id) -> Optional[PlagiarismCheck]:
    try:
        uid = UUID(str(check_id))
    except (ValueError, AttributeError):
        return None
    return db.query(PlagiarismCheck).filter(PlagiarismCheck.id == uid).first()


def delete_check(db: Session, check_id) -> bool:
    row = get_check(db, check_id)
    if not row:
        return False
    db.delete(row)
    db.commit()
    return True