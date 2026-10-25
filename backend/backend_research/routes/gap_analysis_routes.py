"""FastAPI routes for Research Gap Analysis."""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

try:
    from backend_research.database import get_db
    from backend_research.models import (
        GapAnalysis, GapPaper, GapCandidate,
    )
    from backend_research.services import gap_analysis_service as svc
    from backend_research.services.citation_service import (
        _extract_doi_from_url, _fetch_crossref_metadata, _fetch_html,
        _extract_metadata_from_html, _extract_arxiv_id, _fetch_arxiv_metadata
    )
except (ImportError, ModuleNotFoundError):
    from database import get_db
    from models import (
        GapAnalysis, GapPaper, GapCandidate,
    )
    import services.gap_analysis_service as svc
    from services.citation_service import (
        _extract_doi_from_url, _fetch_crossref_metadata, _fetch_html,
        _extract_metadata_from_html, _extract_arxiv_id, _fetch_arxiv_metadata
    )

router = APIRouter(prefix="/api/gap", tags=["gap-analysis"])


# ---------- Schemas ----------
class StartRequest(BaseModel):
    topic: str
    research_question: Optional[str] = None
    keywords: Optional[List[str]] = None
    scope: Optional[dict] = None
    user_id: Optional[int] = None


class PaperInput(BaseModel):
    title: Optional[str] = ""
    abstract: Optional[str] = ""
    authors: Optional[str] = ""
    year: Optional[str] = ""
    venue: Optional[str] = ""
    doi: Optional[str] = ""
    url: Optional[str] = ""
    external_id: Optional[str] = ""


class ValidateGapRequest(BaseModel):
    status: str                # accepted | rejected | uncertain | pending
    user_notes: Optional[str] = None


# ---------- Serializers ----------
def _paper_dict(p: GapPaper) -> dict:
    return {
        "id": p.id, "title": p.title, "authors": p.authors, "year": p.year,
        "venue": p.venue, "doi": p.doi, "url": p.url, "abstract": p.abstract,
        "research_objective": p.research_objective,
        "research_question": p.research_question,
        "population": p.population, "dataset": p.dataset,
        "methodology": p.methodology, "evaluation": p.evaluation,
        "key_findings": p.key_findings, "limitations": p.limitations,
        "future_work": p.future_work,
        "is_extracted": p.is_extracted, "included": p.included,
    }


def _gap_dict(g: GapCandidate) -> dict:
    return {
        "id": g.id, "gap_type": g.gap_type, "description": g.description,
        "evidence_summary": g.evidence_summary,
        "supporting_paper_ids": g.supporting_paper_ids or [],
        "contradictory_paper_ids": g.contradictory_paper_ids or [],
        "confidence": g.confidence,
        "confidence_reason": g.confidence_reason,
        "status": g.status, "user_notes": g.user_notes,
        "directions": [
            {"id": d.id, "research_question": d.research_question,
             "objective": d.objective, "hypothesis": d.hypothesis,
             "status": d.status}
            for d in g.directions
        ],
    }


def _analysis_dict(a: GapAnalysis) -> dict:
    return {
        "id": a.id, "topic": a.topic,
        "research_question": a.research_question,
        "keywords": a.keywords or [], "scope": a.scope or {},
        "status": a.status,
        "papers": [_paper_dict(p) for p in a.papers],
        "gaps": [_gap_dict(g) for g in a.gaps],
    }


# ---------- Endpoints ----------
@router.post("/start")
def start(req: StartRequest, db: Session = Depends(get_db)):
    a = svc.start_analysis(db, req.topic, req.research_question,
                           req.keywords, req.scope, req.user_id)
    return {"analysis_id": a.id, "status": a.status}


@router.get("/list")
def list_analyses(user_id: Optional[int] = None, db: Session = Depends(get_db)):
    q = db.query(GapAnalysis)
    if user_id is not None:
        q = q.filter(GapAnalysis.user_id == user_id)
    rows = q.order_by(GapAnalysis.created_at.desc()).all()
    return [{"id": r.id, "topic": r.topic, "status": r.status,
             "created_at": r.created_at.isoformat() if r.created_at else None}
            for r in rows]


@router.get("/{analysis_id}")
def get_analysis(analysis_id: int, db: Session = Depends(get_db)):
    a = db.query(GapAnalysis).filter(GapAnalysis.id == analysis_id).first()
    if not a:
        raise HTTPException(404, "Analysis not found")
    return _analysis_dict(a)


@router.post("/{analysis_id}/papers")
async def add_papers(analysis_id: int, papers: List[PaperInput],
                     db: Session = Depends(get_db)):
    a = db.query(GapAnalysis).filter(GapAnalysis.id == analysis_id).first()
    if not a:
        raise HTTPException(404, "Analysis not found")
    added = []
    for pi in papers:
        data = pi.model_dump()
        title = (data.get("title") or "").strip()
        url = (data.get("url") or "").strip()
        doi = (data.get("doi") or "").strip()

        # If title is empty, attempt to extract metadata via URL/DOI
        if not title and (url or doi):
            extracted_doi = _extract_doi_from_url(doi) if doi else None
            if not extracted_doi and url:
                extracted_doi = _extract_doi_from_url(url)

            extracted_meta = {}
            if extracted_doi:
                extracted_meta = await _fetch_crossref_metadata(extracted_doi)
                if not doi:
                    doi = extracted_doi

            if not extracted_meta.get("title") and url:
                arxiv_id = _extract_arxiv_id(url)
                if not arxiv_id and doi and "arxiv" in doi.lower():
                    arxiv_id = _extract_arxiv_id(doi)
                if arxiv_id:
                    extracted_meta = await _fetch_arxiv_metadata(arxiv_id)

            if not extracted_meta.get("title") and url and url.startswith("http"):
                html = await _fetch_html(url)
                if html:
                    extracted_meta = _extract_metadata_from_html(html, url)

            if extracted_meta:
                data["title"] = extracted_meta.get("title") or title
                if not data.get("authors") and extracted_meta.get("authors"):
                    data["authors"] = extracted_meta.get("authors")
                if not data.get("year") and extracted_meta.get("year"):
                    data["year"] = extracted_meta.get("year")
                if not data.get("venue"):
                    data["venue"] = extracted_meta.get("journal") or extracted_meta.get("venue") or ""
                if not data.get("doi") and extracted_meta.get("doi"):
                    data["doi"] = extracted_meta.get("doi")
                if not data.get("url") and extracted_meta.get("url"):
                    data["url"] = extracted_meta.get("url")
                if not data.get("abstract") and extracted_meta.get("abstract"):
                    data["abstract"] = extracted_meta.get("abstract")

        if not (data.get("title") or "").strip():
            data["title"] = "Unknown Title"

        p = GapPaper(analysis_id=a.id, **data)
        db.add(p)
        added.append(p)
    db.commit()
    return {"added": len(added), "paper_ids": [p.id for p in added]}


@router.delete("/{analysis_id}/papers/{paper_id}")
def remove_paper(analysis_id: int, paper_id: int, db: Session = Depends(get_db)):
    p = db.query(GapPaper).filter(
        GapPaper.id == paper_id, GapPaper.analysis_id == analysis_id
    ).first()
    if not p:
        raise HTTPException(404, "Paper not found")
    db.delete(p); db.commit()
    return {"deleted": paper_id}


@router.post("/{analysis_id}/extract")
async def extract(analysis_id: int, db: Session = Depends(get_db)):
    a = await svc.run_extraction(db, analysis_id)
    return _analysis_dict(a)


@router.post("/{analysis_id}/detect-gaps")
async def detect(analysis_id: int, db: Session = Depends(get_db)):
    await svc.detect_gaps(db, analysis_id)
    a = db.query(GapAnalysis).filter(GapAnalysis.id == analysis_id).first()
    return _analysis_dict(a)


@router.patch("/{analysis_id}/gaps/{gap_id}")
def validate_gap(analysis_id: int, gap_id: int, req: ValidateGapRequest,
                 db: Session = Depends(get_db)):
    g = db.query(GapCandidate).filter(
        GapCandidate.id == gap_id, GapCandidate.analysis_id == analysis_id
    ).first()
    if not g:
        raise HTTPException(404, "Gap not found")
    if req.status not in ("pending", "accepted", "rejected", "uncertain"):
        raise HTTPException(400, "Invalid status")
    g.status = req.status
    if req.user_notes is not None:
        g.user_notes = req.user_notes
    db.commit()
    return _gap_dict(g)


@router.post("/{analysis_id}/gaps/{gap_id}/direction")
async def direction(analysis_id: int, gap_id: int, db: Session = Depends(get_db)):
    d = await svc.generate_direction(db, gap_id)
    return {"id": d.id, "research_question": d.research_question,
            "objective": d.objective, "hypothesis": d.hypothesis,
            "status": d.status}


@router.post("/{analysis_id}/save")
def save(analysis_id: int, db: Session = Depends(get_db)):
    a = db.query(GapAnalysis).filter(GapAnalysis.id == analysis_id).first()
    if not a:
        raise HTTPException(404, "Analysis not found")
    a.status = "saved"; db.commit()
    return {"status": "saved"}