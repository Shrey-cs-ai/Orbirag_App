from pydantic import BaseModel
from typing import List, Optional

class ChatMessage(BaseModel):
    role: str  # 'user' or 'model'
    content: str

class ChatRequest(BaseModel):
    message: str
    history: Optional[List[ChatMessage]] = []

class ChatResponse(BaseModel):
    response: str

class TranscribeResponse(BaseModel):
    transcript: str
    confidence: float
    duration_seconds: float
    words: int
class PdfChatMessage(BaseModel):
    role: str      # "user" or "model"
    content: str
class PdfChatRequest(BaseModel):
    paper_id: str
    question: str
    history: Optional[List[PdfChatMessage]] = []
class PdfUploadResponse(BaseModel):
    paper_id: str
    filename: str
    chunk_count: int
class PdfChatResponse(BaseModel):
    response: str
    sources: List[dict]   

class AnalyzeRequest(BaseModel):
    text: str
    ignore_words: List[str] = []

class TextStats(BaseModel):
    words: int
    characters: int
    sentences: int

class Suggestion(BaseModel):
    id: str
    type: str  # "spelling", "grammar", "style"
    original: str
    replacement: str
    message: str
    start: int
    end: int

class AnalyzeResponse(BaseModel):
    stats: TextStats
    suggestions: List[Suggestion]
    meta: dict = {}