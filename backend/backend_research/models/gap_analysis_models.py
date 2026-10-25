"""SQLAlchemy models for Research Gap Analysis (re-exported from models.py)."""
try:
    from backend_research.models import (
        GapAnalysis, GapPaper, GapCandidate, GapResearchDirection,
    )
except (ImportError, ModuleNotFoundError):
    from models import (
        GapAnalysis, GapPaper, GapCandidate, GapResearchDirection,
    )

__all__ = ["GapAnalysis", "GapPaper", "GapCandidate", "GapResearchDirection"]