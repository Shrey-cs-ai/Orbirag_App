"""
Orbirag FastAPI backend — Phase 1 + Phase 2 (RAG).
"""

# ============================================================
# STEP 1: Load .env BEFORE importing services
# ============================================================
import os
from pathlib import Path
from services.search_service import search_semantic_scholar
from services.ai_service import build_search_query, summarize_paper
from schemas import (
    BuildQueryRequest, BuildQueryResponse,
    SearchRequest, SearchResponse, PaperResult,
)


def _load_env():
    env_path = Path(__file__).resolve().parent / ".env"
    print(f"[ENV] Loading from: {env_path}")
    if not env_path.exists():
        raise FileNotFoundError(f".env not found at {env_path}")

    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                os.environ[key.strip()] = value.strip()


_load_env()

_gem = os.getenv("GEMINI_API_KEY")
_dg = os.getenv("DEEPGRAM_API_KEY")
print(f"[ENV] GEMINI   : {'OK' if _gem else 'MISSING'}")
print(f"[ENV] DEEPGRAM : {'OK' if _dg else 'MISSING'}")

# ============================================================
# STEP 2: Now safe to import services
# ============================================================
from fastapi import FastAPI, UploadFile, File, HTTPException, Form
from fastapi.middleware.cors import CORSMiddleware

import vector_store
from schemas import (
    ChatRequest, ChatResponse,
    TranscribeResponse,
    UploadPdfResponse,
    RagChatRequest, RagChatResponse,
)
from services.ai_service import get_chat_response
from services.deepgram_service import transcribe_audio
from services.rag_service import index_pdf, ask_document


# ============================================================
# STEP 3: App + middleware
# ============================================================
app = FastAPI(title="Orbirag API", version="0.2.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def _startup():
    # Postgres init — fast, always safe
    try:
        from database import init_db
        init_db()
        print("[DB] Postgres ready")
    except Exception as e:
        print(f"[DB] Skipped: {e}")

    # Vector store — DEFERRED to first PDF upload.
    # (INSTALL vss; LOAD vss; downloads an extension ~30-60s the first time.)
    # vector_store.init_schema()
    print("[Startup] Ready — vector store initializes on first PDF upload")


# ============================================================
# STEP 4: Routes
# ============================================================

@app.get("/")
def read_root():
    return {"message": "Orbirag API is running", "version": "0.2.0"}


# ---------- Ori chatbot ----------

@app.post("/chat", response_model=ChatResponse)
async def chat_endpoint(request: ChatRequest):
    history = [m.model_dump() for m in (request.history or [])]
    text = await get_chat_response(request.message, history)
    return ChatResponse(response=text)


# ---------- Voice ----------

@app.post("/api/voice/transcribe", response_model=TranscribeResponse)
async def transcribe_voice(
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
    if len(audio_bytes) > 10 * 1024 * 1024:
        raise HTTPException(413, "Audio file too large (max 10 MB)")
    if not audio_bytes:
        raise HTTPException(400, "Empty audio file")

    try:
        result = await transcribe_audio(audio_bytes, language=language)
        return TranscribeResponse(**result)
    except RuntimeError as e:
        raise HTTPException(500, str(e))


# ---------- Paper Orbit (RAG) ----------

@app.post("/api/ai/upload-pdf", response_model=UploadPdfResponse)
async def upload_pdf(
    file: UploadFile = File(...),
    user_id: str = Form("anonymous"),
):
    if not file.filename.lower().endswith(".pdf"):
        raise HTTPException(400, "Only PDF files are supported")

    pdf_bytes = await file.read()
    if len(pdf_bytes) > 20 * 1024 * 1024:
        raise HTTPException(413, "PDF too large (max 20 MB)")

    try:
        result = index_pdf(pdf_bytes, file.filename, user_id)
        return UploadPdfResponse(
            doc_id=result["doc_id"],
            filename=file.filename,
            num_chunks=result["num_chunks"],
            num_pages=result["num_pages"],
        )
    except Exception as e:
        raise HTTPException(500, f"Failed to index PDF: {e}")


@app.post("/api/ai/chat-with-pdf", response_model=RagChatResponse)
async def chat_with_pdf(request: RagChatRequest):
    if not vector_store.document_exists(request.doc_id):
        raise HTTPException(404, "Document not found")

    try:
        result = await ask_document(
            request.doc_id, request.message, top_k=request.top_k
        )
        return RagChatResponse(**result)
    except Exception as e:
        raise HTTPException(500, f"RAG error: {e}")

# ============================================================
# Literature Retrieval
# ============================================================

@app.post("/api/ai/build-search", response_model=BuildQueryResponse)
async def build_search_route(req: BuildQueryRequest):
    """Extract keywords + Boolean query from a topic."""
    result = await build_search_query(req.topic)
    if not result:
        raise HTTPException(500, "Could not build search query")

    return BuildQueryResponse(
        keywords=result.get("keywords", []),
        synonyms=result.get("synonyms", []),
        boolean_query=result.get("boolean_query", ""),
    )


@app.post("/api/search", response_model=SearchResponse)
async def search_route(req: SearchRequest):
    """
    Search Semantic Scholar → summarize each result with Gemini.
    Runs summaries in parallel for speed.
    """
    try:
        papers = await search_semantic_scholar(
            query=req.query,
            limit=req.limit,
            year_range=req.date_range,
            discipline=req.discipline,
        )
    except RuntimeError as e:
        raise HTTPException(429, str(e))
    except Exception as e:
        raise HTTPException(500, f"Search failed: {e}")

    if not papers:
        return SearchResponse(results=[], count=0)

    # Summarize in parallel (asyncio.gather)
    import asyncio
    summaries = await asyncio.gather(*[
        summarize_paper(p["title"], p["abstract"]) for p in papers
    ])

    results = [
        PaperResult(**p, ai_summary=s)
        for p, s in zip(papers, summaries)
    ]

    return SearchResponse(results=results, count=len(results))