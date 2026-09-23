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
    sources: List[dict]   # [{"text": "...", "page": 3}, ...]