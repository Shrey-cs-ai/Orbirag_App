"""
Pydantic schemas — request/response shapes for the API.
Keep models.py for SQLAlchemy ORM tables; keep schemas.py for API contracts.
"""

from typing import List, Optional, Literal
from pydantic import BaseModel, Field
from datetime import datetime
import uuid


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
    ai_summary: Optional[str] = ""
    url: Optional[str] = ""
    abstract: Optional[str] = ""
    venue: Optional[str] = ""


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
# Save Paper (Literature)
# ============================================================
from pydantic import BaseModel
from typing import Optional


class SavePaperRequest(BaseModel):
    title: str
    authors: Optional[str] = ""
    year: Optional[str] = ""
    source: Optional[str] = ""
    citations: Optional[int] = 0
    ai_summary: Optional[str] = ""
    url: Optional[str] = ""
    abstract: Optional[str] = ""
    venue: Optional[str] = ""

#library
class LibraryItemCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=500)
    description: str = Field(default="", max_length=5000)
    type: str = Field(..., pattern="^(insight|draft|citation|idea|note)$")
    user_id: Optional[str] = None


class LibraryItemUpdate(BaseModel):
    title: Optional[str] = Field(None, max_length=500)
    description: Optional[str] = Field(None, max_length=5000)
    is_pinned: Optional[bool] = None


class LibraryItemOut(BaseModel):
    id: uuid.UUID
    title: str
    description: str
    type: str
    is_pinned: bool
    created_at: datetime

    class Config:
        from_attributes = True


class LibraryListResponse(BaseModel):
    items: List[LibraryItemOut]
    count: int       
    
#notes
class NoteCreate(BaseModel):
    title: str = Field(default="Untitled", max_length=500)
    content: str = Field(default="", max_length=50000)
    user_id: Optional[str] = None


class NoteUpdate(BaseModel):
    title: Optional[str] = Field(None, max_length=500)
    content: Optional[str] = Field(None, max_length=50000)
    is_pinned: Optional[bool] = None


class NoteOut(BaseModel):
    id: uuid.UUID
    title: str
    content: str
    is_pinned: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class NoteListResponse(BaseModel):
    items: List[NoteOut]
    count: int
    
#user(admin)
class UserCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=64)
    email: Optional[str] = None
    password: str = Field(..., min_length=6, max_length=128)
    role: str = Field(default="user", pattern="^(user|admin)$")


class UserOut(BaseModel):
    id: uuid.UUID
    username: str
    email: Optional[str]
    role: str
    is_active: bool
    created_at: datetime
    last_login: Optional[datetime]

    class Config:
        from_attributes = True


class UserListResponse(BaseModel):
    items: List[UserOut]
    count: int


class LoginRequest(BaseModel):
    username: str
    password: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class PasswordResetRequest(BaseModel):
    new_password: str = Field(..., min_length=6, max_length=128)

class PlagiarismMatch(BaseModel):
    id: int
    text: str
    percentage: str
    words: int
    source: str
    year: str
    excerpt: str


class PlagiarismCheckRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=50000)
    user_id: Optional[str] = None


class PlagiarismCheckResponse(BaseModel):
    id: uuid.UUID
    similarity_score: str
    matches: List[PlagiarismMatch]
    created_at: datetime

    class Config:
        from_attributes = True


class RewriteRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=5000)
    mode: str = Field(..., pattern="^(paraphrase|humanize)$")


class RewriteResponse(BaseModel):
    result: str


class CitationRequest(BaseModel):
    source: str
    year: str = "2023"
    style: str = "APA 7"


class CitationResponse(BaseModel):
    citation: str
# ============================================================
# Legacy aliases (in case older code imports these)
# ============================================================
UploadPdfResponseLegacy = UploadPdfResponse