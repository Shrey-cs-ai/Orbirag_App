"""
Orbirag Chat Backend — Ori chatbot + PDF chat + voice transcription.
"""

import os
from pathlib import Path
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

def _load_env():
    env_path = Path(__file__).resolve().parent / ".env"
    print(f"[ENV] Loading: {env_path}")
    if not env_path.exists():
        raise FileNotFoundError(f".env not found at {env_path}")

    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                os.environ[key.strip()] = value.strip()


_load_env()

print(f"[ENV] GEMINI   : {'OK' if os.getenv('GEMINI_API_KEY') else 'MISSING'}")
print(f"[ENV] DEEPGRAM : {'OK' if os.getenv('DEEPGRAM_API_KEY') else 'MISSING'}")


from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware

# ✅ ADDED — needed for RewriteRequest / RewriteResponse
from pydantic import BaseModel

from models import (
    ChatRequest, ChatResponse,
    TranscribeResponse,
    PdfChatRequest, PdfChatResponse,
    PdfUploadResponse,
    # ✅ Word counter models (must exist in models.py)
    AnalyzeRequest, AnalyzeResponse, TextStats, Suggestion,
)
from services.ai_service import get_chat_response, get_paper_response, get_suggestions
from services.deepgram_service import transcribe_audio
from services.pdf_service import (
    extract_text_from_pdf,
    chunk_text,
    save_paper,
    get_paper,
    find_relevant_chunks,
)
# ✅ Word counter service (new file)
from services.word_counter_service import build_stats


# ============================================================
# App  — ONLY ONE app instance in the whole file
# ============================================================
app = FastAPI(title="Orbirag Chat API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================
# Helpers
# ============================================================
def _validate_file_size(data: bytes, max_mb: int):
    if len(data) == 0:
        raise HTTPException(status_code=400, detail="Empty file")
    if len(data) > max_mb * 1024 * 1024:
        raise HTTPException(status_code=413, detail=f"File too large (max {max_mb} MB)")


def _to_history_dicts(messages):
    return [{"role": m.role, "content": m.content} for m in (messages or [])]


# ============================================================
# Routes
# ============================================================
@app.get("/", tags=["Health"])
def root():
    return {"message": "Orbirag Chat API is running"}


# ---------- Ori Chatbot ----------
@app.post("/chat", response_model=ChatResponse, tags=["Chat"])
async def chat(request: ChatRequest):
    response = await get_chat_response(request.message, request.history)
    return ChatResponse(response=response)


# ---------- Voice ----------
@app.post("/api/voice/transcribe", response_model=TranscribeResponse, tags=["Voice"])
async def voice_transcribe(
    audio: UploadFile = File(...),
    language: str = "en",
):
    allowed = {
        "audio/wav", "audio/x-wav", "audio/wave",
        "audio/mp4", "audio/m4a", "audio/x-m4a",
        "audio/mpeg", "audio/mp3",
        "audio/webm", "audio/ogg",
        "application/octet-stream",
    }
    if audio.content_type not in allowed:
        raise HTTPException(400, f"Unsupported audio type: {audio.content_type}")

    audio_bytes = await audio.read()
    _validate_file_size(audio_bytes, max_mb=10)

    try:
        result = await transcribe_audio(audio_bytes, language=language)
        return TranscribeResponse(**result)
    except RuntimeError as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------- Paper Orbit: Upload PDF ----------
@app.post("/upload-pdf", response_model=PdfUploadResponse, tags=["Paper Orbit"])
async def upload_pdf(file: UploadFile = File(...)):
    if file.content_type not in {"application/pdf", "application/octet-stream"}:
        raise HTTPException(400, f"Only PDF files allowed. Got: {file.content_type}")

    pdf_bytes = await file.read()
    _validate_file_size(pdf_bytes, max_mb=20)

    try:
        pages = extract_text_from_pdf(pdf_bytes)
        if not pages:
            raise HTTPException(400, "Could not extract text from PDF")

        chunks = chunk_text(pages, chunk_size=800, overlap=100)
        paper_id = save_paper(file.filename or "untitled.pdf", chunks)

        return PdfUploadResponse(
            paper_id=paper_id,
            filename=file.filename or "untitled.pdf",
            chunk_count=len(chunks),
        )
    except HTTPException:
        raise
    except Exception as e:
        print(f"[PDF] Upload error: {type(e).__name__}: {e}")
        raise HTTPException(500, f"Upload failed: {e}")


# ---------- Paper Orbit: Chat with PDF ----------
@app.post("/chat-with-pdf", response_model=PdfChatResponse, tags=["Paper Orbit"])
async def chat_with_pdf(request: PdfChatRequest):
    paper = get_paper(request.paper_id)
    if not paper:
        raise HTTPException(404, "Paper not found")

    relevant = find_relevant_chunks(request.question, paper["chunks"], top_k=3)

    if not relevant:
        return PdfChatResponse(
            response="I couldn't find relevant information in this paper.",
            sources=[],
        )

    context = "\n\n".join(f"[Page {c['page']}]\n{c['text']}" for c in relevant)

    response = await get_paper_response(
        question=request.question,
        context=context,
        history=_to_history_dicts(request.history),
    )

    return PdfChatResponse(response=response, sources=relevant)


# ============================================================
# AI Rewrite (Paraphrase / Humanize)
# ============================================================
class RewriteRequest(BaseModel):
    text: str
    mode: str   # "paraphrase" or "humanize"


class RewriteResponse(BaseModel):
    result: str


REWRITE_PROMPTS = {
    "paraphrase": """You are an academic writing assistant. Paraphrase the text below
to reduce plagiarism while preserving the meaning. Use different vocabulary and
sentence structure. Keep it professional and academic. Return ONLY the rewritten
text — no explanations, no quotes.

TEXT:
{text}

PARAPHRASED:""",

    "humanize": """You are an academic writing assistant. Rewrite the text below
to sound more natural, human, and less AI-generated. Use varied sentence lengths,
natural transitions, and a conversational-but-professional tone. Preserve the
original meaning. Return ONLY the rewritten text — no explanations.

TEXT:
{text}

HUMANIZED:""",
}


@app.post("/api/ai/rewrite", response_model=RewriteResponse, tags=["Plagiarism"])
async def rewrite_route(req: RewriteRequest):
    """Paraphrase or humanize a piece of text using Gemini."""
    text = (req.text or "").strip()
    if not text:
        raise HTTPException(400, "Empty text")
    if len(text) > 5000:
        raise HTTPException(413, "Text too long (max 5000 chars)")

    mode = req.mode.lower().strip()
    if mode not in REWRITE_PROMPTS:
        raise HTTPException(400, f"Invalid mode: {mode}. Use 'paraphrase' or 'humanize'.")

    prompt = REWRITE_PROMPTS[mode].format(text=text)

    try:
        result = await _generate_with_fallback(prompt)
        return RewriteResponse(result=(result or "").strip())
    except Exception as e:
        print(f"[Rewrite] error: {type(e).__name__}: {e}")
        raise HTTPException(500, f"Rewrite failed: {e}")


# ============================================================
# Word Counter
# ============================================================
@app.post("/api/analyze", response_model=AnalyzeResponse, tags=["Word Counter"])
async def analyze_text(request: AnalyzeRequest):
    text = request.text
    ignore_words = request.ignore_words

    if len(text) > 10000:
        raise HTTPException(status_code=413, detail="Text too long. Max 10000 characters.")

    stats_dict = build_stats(text)
    suggestions_list = await get_suggestions(text, ignore_words)

    return AnalyzeResponse(
        stats=TextStats(**stats_dict),
        suggestions=[Suggestion(**s) for s in suggestions_list],
        meta={"ignored": len(ignore_words)},
    )
    
#library
