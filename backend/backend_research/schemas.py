"""
Pydantic schemas — request/response shapes for the API.
Keep models.py for SQLAlchemy ORM tables; keep schemas.py for API contracts.
"""

from typing import List, Optional, Literal
from pydantic import BaseModel, Field


# ============================================================
# Chat (Ori)
# ============================================================

class ChatMessage(BaseModel):
    role: Literal["user", "assistant", "model"]
    content: str


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=4000)
    history: Optional[List[ChatMessage]] = []


class ChatResponse(BaseModel):
    response: str


# ============================================================
# Voice (Deepgram)
# ============================================================

class TranscribeResponse(BaseModel):
    transcript: str
    confidence: float = 0.0
    duration_seconds: float = 0.0
    words: int = 0


# ============================================================
# Paper Orbit (RAG)
# ============================================================

class UploadPdfResponse(BaseModel):
    doc_id: str
    filename: str
    num_chunks: int
    num_pages: int
    message: str = "PDF indexed successfully"


class RagChatRequest(BaseModel):
    doc_id: str
    message: str = Field(..., min_length=1, max_length=2000)
    top_k: int = Field(5, ge=1, le=15)


class RagSource(BaseModel):
    page: int
    chunk_index: int
    snippet: str          # short preview of the chunk


class RagChatResponse(BaseModel):
    response: str
    sources: List[RagSource] = []


# ============================================================
# Saved Papers (for SavedPapersScreen)
# ============================================================

class SavePaperRequest(BaseModel):
    title: str
    authors: str
    year: str
    url: Optional[str] = None
    abstract: Optional[str] = None
    source: Optional[str] = None
    citations: Optional[int] = 0


class SavedPaper(BaseModel):
    id: str
    title: str
    authors: str
    year: str
    url: Optional[str] = None
    created_at: str


# ============================================================
# Citation Generator
# ============================================================

class CitationRequest(BaseModel):
    doi_or_url: str
    style: Literal["APA 7", "MLA 9", "Chicago", "IEEE", "Harvard"] = "APA 7"


class CitationResponse(BaseModel):
    title: str
    authors: str
    year: str
    journal: str
    in_text: str
    reference: str

# ============================================================
# Literature Retrieval
# ============================================================

class BuildQueryRequest(BaseModel):
    topic: str = Field(..., min_length=2, max_length=2000)


class BuildQueryResponse(BaseModel):
    keywords: List[str] = []
    synonyms: List[str] = []
    boolean_query: str = ""


class SearchRequest(BaseModel):
    query: str = Field(..., min_length=2, max_length=2000)
    date_range: Optional[str] = "2015-2025"
    discipline: Optional[str] = "All"
    limit: int = Field(10, ge=1, le=25)


class PaperResult(BaseModel):
    id: str
    title: str
    authors: str
    year: str
    abstract: str = ""
    url: str = ""
    citations: int = 0
    venue: str = ""
    source: str = "Semantic Scholar"
    ai_summary: str = ""


class SearchResponse(BaseModel):
    results: List[PaperResult] = []
    count: int = 0  
    
# ============================================================
# Legacy aliases (in case older code imports these)
# ============================================================
UploadPdfResponseLegacy = UploadPdfResponse