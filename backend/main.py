# ============================================================
# 1. LOAD .ENV FIRST (before any service imports)
# ============================================================
import os
from pathlib import Path


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
# Voice (Deepgram) disabled — will re-enable in next push
# print(f"[ENV] DEEPGRAM : {'OK' if os.getenv('DEEPGRAM_API_KEY') else 'MISSING'}")
# ============================================================


# ============================================================
# 2. IMPORTS
# ============================================================
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware

# Models
from models import (
    ChatRequest,
    ChatResponse,
    # TranscribeResponse,   # ← Voice (disabled)
    PdfChatRequest,
    PdfChatResponse,
    PdfUploadResponse,
)

# Services
from services.ai_service import get_chat_response, get_paper_response
# from services.deepgram_service import transcribe_audio   # ← Voice (disabled)
from services.pdf_service import (
    extract_text_from_pdf,
    chunk_text,
    save_paper,
    get_paper,
    find_relevant_chunks,
)


# ============================================================
# 3. APP SETUP
# ============================================================
app = FastAPI(title="Orbirag API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================
# 4. HELPER FUNCTIONS
# ============================================================

def _validate_file_size(data: bytes, max_mb: int):
    """Raise if file is empty or too large."""
    if len(data) == 0:
        raise HTTPException(status_code=400, detail="Empty file")
    if len(data) > max_mb * 1024 * 1024:
        raise HTTPException(
            status_code=413,
            detail=f"File too large (max {max_mb} MB)",
        )


def _to_history_dicts(messages):
    """Convert Pydantic chat history → list of dicts."""
    return [
        {"role": m.role, "content": m.content}
        for m in (messages or [])
    ]


# ============================================================
# 5. ROUTES
# ============================================================

# ---------- Health Check ----------
@app.get("/", tags=["Health"])
def root():
    return {"message": "Orbirag API is running"}


# ---------- Ori Chatbot ----------
@app.post("/chat", response_model=ChatResponse, tags=["Chat"])
async def chat(request: ChatRequest):
    """General chat with Ori."""
    response = await get_chat_response(request.message, request.history)
    return ChatResponse(response=response)


# ---------- Voice Input ----------
# TEMPORARILY DISABLED — will re-enable in next push
#
# @app.post(
#     "/api/voice/transcribe",
#     response_model=TranscribeResponse,
#     tags=["Voice"],
# )
# async def voice_transcribe(
#     audio: UploadFile = File(...),
#     language: str = "en",
# ):
#     """Convert audio file → text using Deepgram."""
#     allowed = {
#         "audio/wav", "audio/x-wav", "audio/wave",
#         "audio/mp4", "audio/m4a", "audio/x-m4a",
#         "audio/mpeg", "audio/mp3",
#         "audio/webm", "audio/ogg",
#         "application/octet-stream",
#     }
#     if audio.content_type not in allowed:
#         raise HTTPException(
#             status_code=400,
#             detail=f"Unsupported audio type: {audio.content_type}",
#         )
#
#     audio_bytes = await audio.read()
#     _validate_file_size(audio_bytes, max_mb=10)
#
#     try:
#         result = await transcribe_audio(audio_bytes, language=language)
#         return TranscribeResponse(**result)
#     except RuntimeError as e:
#         raise HTTPException(status_code=500, detail=str(e))


# ---------- Paper Orbit: Upload PDF ----------
@app.post(
    "/upload-pdf",
    response_model=PdfUploadResponse,
    tags=["Paper Orbit"],
)
async def upload_pdf(file: UploadFile = File(...)):
    """Upload a PDF → extract text → chunk → store in memory."""
    if file.content_type not in {"application/pdf", "application/octet-stream"}:
        raise HTTPException(
            status_code=400,
            detail=f"Only PDF files allowed. Got: {file.content_type}",
        )

    pdf_bytes = await file.read()
    _validate_file_size(pdf_bytes, max_mb=20)

    try:
        pages = extract_text_from_pdf(pdf_bytes)
        if not pages:
            raise HTTPException(
                status_code=400,
                detail="Could not extract text from PDF",
            )

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
        raise HTTPException(status_code=500, detail=f"Upload failed: {e}")


# ---------- Paper Orbit: Chat with PDF ----------
@app.post(
    "/chat-with-pdf",
    response_model=PdfChatResponse,
    tags=["Paper Orbit"],
)
async def chat_with_pdf(request: PdfChatRequest):
    """Ask a question about an uploaded PDF."""
    paper = get_paper(request.paper_id)
    if not paper:
        raise HTTPException(status_code=404, detail="Paper not found")

    relevant = find_relevant_chunks(
        request.question,
        paper["chunks"],
        top_k=3,
    )

    if not relevant:
        return PdfChatResponse(
            response="I couldn't find relevant information in this paper.",
            sources=[],
        )

    context = "\n\n".join(
        f"[Page {c['page']}]\n{c['text']}" for c in relevant
    )

    response = await get_paper_response(
        question=request.question,
        context=context,
        history=_to_history_dicts(request.history),
    )

    return PdfChatResponse(response=response, sources=relevant)