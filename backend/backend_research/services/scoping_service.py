"""
Guided Topic Scoping — parses a rough topic into PICO and
synthesizes a research question using Gemini.
"""

import json
import re
from typing import Optional, List

from sqlalchemy.orm import Session
from sqlalchemy import desc

from models import ScopingSession


# ============================================================
# Gemini — goes through the fallback chain
# ============================================================
async def _ask_gemini(prompt: str, temperature: Optional[float] = None) -> dict:
    from services.ai_service import _generate_with_fallback
    raw = await _generate_with_fallback(prompt, json_mode=True, temperature=temperature)
    raw = (raw or "").strip()
    if raw.startswith("```"):
        raw = re.sub(r"^```(?:json)?\s*|\s*```$", "", raw, flags=re.MULTILINE)
    return json.loads(raw)


# ============================================================
# Prompt templates
# ============================================================
_PARSE_PROMPT = """You are a research methods assistant.

Read the rough research topic inside <topic> tags. Extract a PICO
structure. Return ONLY valid JSON in this exact shape:

{{
  "population": "who or what is being studied",
  "intervention": "the main thing being studied",
  "comparison": "comparison group (empty string if not implied)",
  "outcome": "the main outcome being measured"
}}

Rules:
- Only infer what the topic reasonably implies. Do NOT invent details.
- Each field must be a short noun phrase, under 15 words.
- comparison MUST be empty ("") if the topic doesn't mention one.

<topic>{topic}</topic>
"""

_SYNTHESIZE_PROMPT = """You are a research methods assistant.

Combine the following PICO elements into ONE clear, well-phrased research question.
Produce a fresh variation of the question using precise and engaging academic phrasing.
Return ONLY valid JSON in this shape: {{"research_question": "..."}}

Rules:
- One neutral sentence ending with a question mark.
- Include comparison only if it is non-empty.
- Do not presuppose the answer.
- Keep it under 40 words.

POPULATION: {population}
INTERVENTION: {intervention}
COMPARISON: {comparison}
OUTCOME: {outcome}
"""


# ============================================================
# Public: parse topic → PICO
# ============================================================
async def parse_topic(topic: str) -> dict:
    prompt = _PARSE_PROMPT.format(topic=topic[:800])
    data = await _ask_gemini(prompt)

    return {
        "topic": topic,
        "population": (data.get("population") or "").strip(),
        "intervention": (data.get("intervention") or "").strip(),
        "comparison": (data.get("comparison") or "").strip(),
        "outcome": (data.get("outcome") or "").strip(),
        "research_question": "",
    }


# ============================================================
# Public: synthesize research question
# ============================================================
async def synthesize_question(payload: dict) -> str:
    if not payload.get("population"):
        raise ValueError("population is required")
    if not payload.get("intervention"):
        raise ValueError("intervention is required")
    if not payload.get("outcome"):
        raise ValueError("outcome is required")

    prompt = _SYNTHESIZE_PROMPT.format(
        population=payload.get("population", ""),
        intervention=payload.get("intervention", ""),
        comparison=payload.get("comparison", "") or "(none)",
        outcome=payload.get("outcome", ""),
    )
    data = await _ask_gemini(prompt, temperature=0.8)
    return (data.get("research_question") or "").strip()


# ============================================================
# DB CRUD
# ============================================================
def save_session(
    db: Session,
    payload: dict,
    user_id: Optional[str] = None,
) -> ScopingSession:
    row = ScopingSession(
        user_id=user_id,
        raw_topic=payload.get("topic") or "",
        population=payload.get("population") or "",
        intervention=payload.get("intervention") or "",
        comparison=payload.get("comparison") or "",
        outcome=payload.get("outcome") or "",
        research_question=payload.get("research_question") or "",
        status="completed",
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def list_sessions(db: Session, user_id: Optional[str] = None) -> List[ScopingSession]:
    q = db.query(ScopingSession)
    if user_id:
        q = q.filter(ScopingSession.user_id == user_id)
    return q.order_by(desc(ScopingSession.created_at)).all()


def get_session(db: Session, session_id) -> Optional[ScopingSession]:
    from uuid import UUID
    try:
        uid = UUID(str(session_id))
    except (ValueError, AttributeError):
        return None
    return db.query(ScopingSession).filter(ScopingSession.id == uid).first()


def to_dict(row: ScopingSession) -> dict:
    return {
        "id": row.id,
        "topic": row.raw_topic or "",
        "population": row.population or "",
        "intervention": row.intervention or "",
        "comparison": row.comparison or "",
        "outcome": row.outcome or "",
        "research_question": row.research_question or "",
        "created_at": row.created_at,
    }