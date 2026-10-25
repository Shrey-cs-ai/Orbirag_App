"""Business logic + AI for Research Gap Analysis."""
import os, json, re
from typing import List, Optional, Dict, Any
import httpx
from sqlalchemy.orm import Session
from fastapi import HTTPException

try:
    from backend_research.models import (
        GapAnalysis, GapPaper, GapCandidate, GapResearchDirection,
    )
except (ImportError, ModuleNotFoundError):
    from models import (
        GapAnalysis, GapPaper, GapCandidate, GapResearchDirection,
    )

# ---- AI config ----
AI_BASE_URL = os.getenv("AI_BASE_URL") or ("https://api.groq.com/openai/v1" if os.getenv("GROQ_API_KEY") and not os.getenv("OPENAI_API_KEY") else "https://api.openai.com/v1")
AI_API_KEY  = os.getenv("OPENAI_API_KEY") or os.getenv("GROQ_API_KEY", "")
AI_MODEL    = os.getenv("AI_MODEL") or ("openai/gpt-oss-120b" if (os.getenv("GROQ_API_KEY") and not os.getenv("OPENAI_API_KEY")) else "gpt-4o-mini")


async def _call_llm_json(system: str, user: str, max_tokens: int = 2000) -> Any:
    """Call an OpenAI-compatible chat endpoint, return parsed JSON."""
    api_key = os.getenv("OPENAI_API_KEY") or os.getenv("GROQ_API_KEY") or AI_API_KEY
    base_url = os.getenv("AI_BASE_URL") or ("https://api.groq.com/openai/v1" if os.getenv("GROQ_API_KEY") and not os.getenv("OPENAI_API_KEY") else AI_BASE_URL)
    model = os.getenv("AI_MODEL") or ("openai/gpt-oss-120b" if os.getenv("GROQ_API_KEY") and not os.getenv("OPENAI_API_KEY") else AI_MODEL)

    if not api_key:
        raise HTTPException(status_code=500, detail="AI_API_KEY not configured")

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "response_format": {"type": "json_object"},
        "temperature": 0.2,
        "max_tokens": max_tokens,
    }
    async with httpx.AsyncClient(timeout=90.0) as client:
        r = await client.post(
            f"{base_url}/chat/completions",
            headers={"Authorization": f"Bearer {api_key}"},
            json=payload,
        )
    if r.status_code != 200:
        raise HTTPException(status_code=502, detail=f"AI error: {r.text[:300]}")

    content = r.json()["choices"][0]["message"]["content"]
    try:
        return json.loads(content)
    except json.JSONDecodeError:
        # Try to salvage JSON from within the text
        m = re.search(r"\{.*\}|\[.*\]", content, re.DOTALL)
        if m:
            return json.loads(m.group(0))
        raise HTTPException(status_code=502, detail="AI returned non-JSON")


# ============================================================
# Step 1 — Start an analysis
# ============================================================
def start_analysis(db: Session, topic: str, research_question: Optional[str],
                   keywords: Optional[List[str]], scope: Optional[Dict],
                   user_id: Optional[int] = None) -> GapAnalysis:
    analysis = GapAnalysis(
        user_id=user_id, topic=topic.strip(),
        research_question=research_question,
        keywords=keywords or [],
        scope=scope or {},
        status="draft",
    )
    db.add(analysis); db.commit(); db.refresh(analysis)
    return analysis


# ============================================================
# Step 3/4 — Add paper + extract structured evidence
# ============================================================
async def extract_evidence_for_paper(paper: GapPaper) -> None:
    """Extract structured fields for a single paper using the LLM."""
    text = (paper.abstract or "").strip() or f"Title: {paper.title}"
    system = (
        "You are a research analyst. Given a paper's title and abstract, extract "
        "structured information. Return ONLY valid JSON with this exact schema:\n"
        '{\n'
        '  "research_objective": "string",\n'
        '  "research_question": "string or null",\n'
        '  "population": "string",\n'
        '  "dataset": "string",\n'
        '  "methodology": "string",\n'
        '  "evaluation": "string",\n'
        '  "key_findings": "string",\n'
        '  "limitations": "string",\n'
        '  "future_work": "string"\n'
        '}\n'
        "If information is missing, use an empty string. Do not invent facts."
    )
    user = f"Title: {paper.title}\nAuthors: {paper.authors or 'unknown'}\nYear: {paper.year or 'unknown'}\nAbstract: {text}"
    data = await _call_llm_json(system, user, max_tokens=800)

    paper.research_objective = data.get("research_objective", "")
    paper.research_question  = data.get("research_question", "") or ""
    paper.population         = data.get("population", "")
    paper.dataset            = data.get("dataset", "")
    paper.methodology        = data.get("methodology", "")
    paper.evaluation         = data.get("evaluation", "")
    paper.key_findings       = data.get("key_findings", "")
    paper.limitations        = data.get("limitations", "")
    paper.future_work        = data.get("future_work", "")
    paper.is_extracted = True


async def run_extraction(db: Session, analysis_id: int) -> GapAnalysis:
    analysis = db.query(GapAnalysis).filter(GapAnalysis.id == analysis_id).first()
    if not analysis:
        raise HTTPException(status_code=404, detail="Analysis not found")

    analysis.status = "extracting"; db.commit()

    papers = [p for p in analysis.papers if p.included and not p.is_extracted]
    for p in papers:
        try:
            await extract_evidence_for_paper(p)
            db.commit()
        except Exception as e:
            print(f"[Gap] extraction failed for paper {p.id}: {e}")
            db.rollback()

    analysis.status = "analyzed"; db.commit(); db.refresh(analysis)
    return analysis


# ============================================================
# Step 7/8/9 — Detect patterns, generate gaps, score confidence
# ============================================================
def _paper_matrix_text(papers: List[GapPaper]) -> str:
    rows = []
    for p in papers:
        rows.append({
            "paper_id": p.id,
            "title": p.title,
            "year": p.year,
            "objective": p.research_objective,
            "population": p.population,
            "dataset": p.dataset,
            "methodology": p.methodology,
            "evaluation": p.evaluation,
            "findings": p.key_findings,
            "limitations": p.limitations,
            "future_work": p.future_work,
        })
    return json.dumps(rows, ensure_ascii=False)


async def detect_gaps(db: Session, analysis_id: int) -> List[GapCandidate]:
    analysis = db.query(GapAnalysis).filter(GapAnalysis.id == analysis_id).first()
    if not analysis:
        raise HTTPException(status_code=404, detail="Analysis not found")

    papers = [p for p in analysis.papers if p.included and p.is_extracted]
    if len(papers) < 2:
        raise HTTPException(status_code=400,
                            detail="Need at least 2 extracted papers to detect gaps")

    system = (
        "You are a research gap analyst. Given a matrix of papers (JSON), "
        "identify potential research gaps across these categories:\n"
        "- population (group under-studied)\n"
        "- geographic (region/setting under-studied)\n"
        "- methodological (design or evaluation missing)\n"
        "- dataset (data small/biased/outdated)\n"
        "- temporal (older work, not updated)\n"
        "- contradiction (conflicting findings)\n"
        "- application (method works in lab, untested in real world)\n"
        "- theoretical (mechanism not explained)\n"
        "- evaluation (metrics/baselines missing)\n\n"
        "Every gap MUST be evidence-backed. Use specific numbers from the papers. "
        "Return ONLY valid JSON:\n"
        '{"gaps": [{\n'
        '  "gap_type": "one of the categories above",\n'
        '  "description": "clear 1-2 sentence gap statement",\n'
        '  "evidence_summary": "e.g. 8 of 11 papers use controlled datasets; 2 report field tests",\n'
        '  "supporting_paper_ids": [list of paper_id integers],\n'
        '  "contradictory_paper_ids": [list of paper_id integers, or empty],\n'
        '  "confidence": "high|moderate|low|unverified",\n'
        '  "confidence_reason": "why not high (e.g. search may miss unpublished work)"\n'
        '}]}\n'
        "Only include gaps you can support with the given evidence. "
        "Aim for 3-8 strong gaps, not 20 weak ones."
    )
    user = f"Topic: {analysis.topic}\n\nPaper matrix:\n{_paper_matrix_text(papers)}"
    data = await _call_llm_json(system, user, max_tokens=2500)

    # Clear old gaps (re-run support)
    for old in list(analysis.gaps):
        db.delete(old)
    db.flush()

    valid_ids = {p.id for p in papers}
    created = []
    for g in data.get("gaps", []):
        supporting = [int(i) for i in g.get("supporting_paper_ids", []) if int(i) in valid_ids]
        contradict = [int(i) for i in g.get("contradictory_paper_ids", []) if int(i) in valid_ids]
        conf = g.get("confidence", "unverified").lower()
        if conf not in ("high", "moderate", "low", "unverified"):
            conf = "unverified"
        if not supporting:
            continue  # skip gaps with no evidence

        gc = GapCandidate(
            analysis_id=analysis.id,
            gap_type=g.get("gap_type", "methodological"),
            description=g.get("description", ""),
            evidence_summary=g.get("evidence_summary", ""),
            supporting_paper_ids=supporting,
            contradictory_paper_ids=contradict,
            confidence=conf,
            confidence_reason=g.get("confidence_reason", ""),
        )
        db.add(gc); created.append(gc)

    db.commit()
    return created


# ============================================================
# Step 11 — Gap → research direction
# ============================================================
async def generate_direction(db: Session, gap_id: int) -> GapResearchDirection:
    gap = db.query(GapCandidate).filter(GapCandidate.id == gap_id).first()
    if not gap:
        raise HTTPException(status_code=404, detail="Gap not found")

    system = (
        "Given a research gap, propose ONE candidate research direction. "
        "Return ONLY valid JSON:\n"
        '{"research_question": "string", "objective": "string", "hypothesis": "string or null"}'
    )
    user = f"Gap type: {gap.gap_type}\nGap: {gap.description}\nEvidence: {gap.evidence_summary}"
    data = await _call_llm_json(system, user, max_tokens=500)

    direction = GapResearchDirection(
        gap_id=gap.id,
        research_question=data.get("research_question", ""),
        objective=data.get("objective", ""),
        hypothesis=data.get("hypothesis", "") or "",
    )
    db.add(direction); db.commit(); db.refresh(direction)
    return direction