"""
Methodology extraction: parses a methods section into structured
research-design fields using Gemini.
"""

import os
import json
import re
from typing import Optional
from uuid import UUID

from sqlalchemy.orm import Session
from sqlalchemy import desc

from models import Methodology


# ============================================================
# Gemini
# ============================================================
def _gemini_model():
    import google.generativeai as genai
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY not set")
    genai.configure(api_key=api_key)
    return genai.GenerativeModel("gemini-3.8-flash")


_EXTRACT_PROMPT = """You are an academic methods-section analyzer.

Read the METHODS text below and extract structured fields. Return ONLY valid
JSON in this exact shape:

{{
  "study_type": "quantitative | qualitative | mixed-methods | systematic-review | case-study | other",
  "design": "e.g., RCT, cohort, cross-sectional, interview study",
  "sample_size": "e.g., n=240",
  "sampling_method": "e.g., random, stratified, purposive, snowball",
  "data_collection": "e.g., survey, interview, experiment, observation",
  "analysis_method": "e.g., regression, thematic analysis, t-test",
  "databases_searched": "e.g., PubMed, Scopus, IEEE Xplore (only for systematic reviews)",
  "inclusion_criteria": "only for systematic reviews",
  "exclusion_criteria": "only for systematic reviews",
  "studies_included_count": "e.g., 42 (only for systematic reviews)",
  "additional_notes": "1-2 sentence summary of methodology"
}}

Rules:
- Use empty string "" when a field is not mentioned
- Do NOT invent information not present in the text
- Keep each field concise (1-2 lines max)
- Return ONLY the JSON, no explanation

TEXT:
\"\"\"
{text}
\"\"\"
"""


async def extract(text: str) -> dict:
    model = _gemini_model()
    response = model.generate_content(
        _EXTRACT_PROMPT.format(text=text[:8000]),
        generation_config={
            "temperature": 0.2,
            "response_mime_type": "application/json",
        },
    )
    raw = response.text.strip()

    if raw.startswith("```"):
        raw = re.sub(r"^```(?:json)?\s*|\s*```$", "", raw, flags=re.MULTILINE)

    try:
        data = json.loads(raw)
    except Exception as e:
        print(f"[Methodology] parse failed: {e} — raw: {raw[:200]}")
        data = {}

    keys = [
        "study_type", "design", "sample_size", "sampling_method",
        "data_collection", "analysis_method", "databases_searched",
        "inclusion_criteria", "exclusion_criteria",
        "studies_included_count", "additional_notes",
    ]
    result = {k: (data.get(k) or "").strip() for k in keys}
    result["raw_highlighted_text"] = text
    return result


def save(
    db: Session,
    raw_text: str,
    data: dict,
    paper_title: Optional[str] = None,
    user_id: Optional[str] = None,
) -> Methodology:
    row = Methodology(
        user_id=user_id,
        paper_title=paper_title,
        raw_text=raw_text,
        study_type=data.get("study_type"),
        design=data.get("design"),
        sample_size=data.get("sample_size"),
        sampling_method=data.get("sampling_method"),
        data_collection=data.get("data_collection"),
        analysis_method=data.get("analysis_method"),
        databases_searched=data.get("databases_searched"),
        inclusion_criteria=data.get("inclusion_criteria"),
        exclusion_criteria=data.get("exclusion_criteria"),
        studies_included_count=data.get("studies_included_count"),
        additional_notes=data.get("additional_notes"),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def to_data_dict(row: Methodology) -> dict:
    return {
        "study_type": row.study_type or "",
        "design": row.design or "",
        "sample_size": row.sample_size or "",
        "sampling_method": row.sampling_method or "",
        "data_collection": row.data_collection or "",
        "analysis_method": row.analysis_method or "",
        "databases_searched": row.databases_searched or "",
        "inclusion_criteria": row.inclusion_criteria or "",
        "exclusion_criteria": row.exclusion_criteria or "",
        "studies_included_count": row.studies_included_count or "",
        "additional_notes": row.additional_notes or "",
        "raw_highlighted_text": row.raw_text or "",
    }