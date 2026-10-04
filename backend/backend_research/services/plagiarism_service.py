"""
Plagiarism service: AI similarity analysis, paraphrase/humanize, citation, DB CRUD.
"""

import os
import json
import re
from typing import List, Optional
from uuid import UUID

from sqlalchemy.orm import Session
from sqlalchemy import desc

from models import PlagiarismCheck


# ============================================================
# Gemini
# ============================================================
def _gemini_model():
    import google.generativeai as genai
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY not set")
    genai.configure(api_key=api_key)
    return genai.GenerativeModel("gemini-2.0-flash")


async def analyze_text(text: str) -> dict:
    """
    Returns:
      {
        "similarity_score": "18%",
        "matches": [{id, text, percentage, words, source, year, excerpt}, ...]
      }
    """
    model = _gemini_model()

    prompt = f"""You are an academic integrity analyzer.

Analyze the text below for potential plagiarism. Return ONLY valid JSON in this shape:

{{
  "similarity_score": "<integer>%",
  "matches": [
    {{
      "text": "<exact substring from the input text>",
      "percentage": "<integer>%",
      "source": "<plausible academic paper title>",
      "year": "<4-digit year>",
      "excerpt": "<short 10-15 word excerpt from source>"
    }}
  ]
}}

Rules:
- "similarity_score" is 0-100
- Each match "text" MUST be an exact substring of the input
- Provide 0-4 matches. If the text looks original, return an empty list and a score below 20
- Sources should be plausible academic paper titles
- Do NOT include any explanation outside the JSON

TEXT:
\"\"\"{text[:8000]}\"\"\"
"""

    response = model.generate_content(
        prompt,
        generation_config={
            "temperature": 0.2,
            "response_mime_type": "application/json",
        },
    )

    raw = response.text.strip()
    if raw.startswith("```"):
        raw = re.sub(r"^```(?:json)?\s*|\s*```$", "", raw, flags=re.MULTILINE)

    data = json.loads(raw)

    matches = []
    for i, m in enumerate(data.get("matches", []), start=1):
        t = (m.get("text") or "").strip()
        if not t or t not in text:
            continue
        matches.append({
            "id": i,
            "text": t,
            "percentage": m.get("percentage", "0%"),
            "words": len(t.split()),
            "source": m.get("source", "Unknown source"),
            "year": str(m.get("year", "2023")),
            "excerpt": m.get("excerpt", ""),
        })

    return {
        "similarity_score": data.get("similarity_score", "0%"),
        "matches": matches,
    }


# ============================================================
# Paraphrase / Humanize
# ============================================================
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
    model = _gemini_model()
    prompt = _PROMPTS[mode].format(text=text)
    response = model.generate_content(
        prompt,
        generation_config={"temperature": 0.7},
    )
    return response.text.strip()


# ============================================================
# Citation
# ============================================================
def format_citation(source: str, year: str = "2023", style: str = "APA 7") -> str:
    first_word = source.split()[0].strip(",.") if source else "Unknown"
    return f"({first_word}, {year})"


# ============================================================
# DB CRUD
# ============================================================
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
