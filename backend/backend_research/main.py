"""
Orbirag FastAPI backend — Phase 1 + Phase 2 (RAG).
"""

# ============================================================
# STEP 1: Load .env BEFORE importing services
# ============================================================
import os
import asyncio  
from pydantic import BaseModel, Field
from typing import Optional
from pathlib import Path
from models import User
from services.search_service import search_semantic_scholar
from services.ai_service import build_search_query, summarize_paper
from schemas import (
    BuildQueryRequest, BuildQueryResponse, CitationGenerateRequest, CitationGenerateResponse,
    SearchRequest, SearchResponse, PaperResult,
)
from fastapi import Depends
from sqlalchemy.orm import Session
from uuid import UUID

from database import get_db, init_db
from schemas import (
    LibraryItemCreate,
    LibraryItemUpdate,
    LibraryItemOut,
    LibraryListResponse,
)
from services import library_service

from schemas import (
    # ... existing library imports ...
    NoteCreate,
    NoteUpdate,
    NoteOut,
    NoteListResponse,
)
from services import notes_service

from schemas import (
    # ... existing ...
    UserCreate, UserOut, UserListResponse,
    LoginRequest, LoginResponse, PasswordResetRequest,
    AdminPasswordResetRequest, AvatarUpdateRequest,
)
from services import user_service
from services.deps import get_current_user, require_admin
from services.auth_service import verify_password, create_access_token
from datetime import datetime, timezone
from sqlalchemy import Column, String, Boolean, Text, DateTime, func
from schemas import (
    # ... existing ...
    PlagiarismCheckRequest, PlagiarismCheckResponse, PlagiarismMatch,
    RewriteRequest, RewriteResponse,
    CitationRequest, CitationResponse,
)
from services import plagiarism_service

from services import citation_service

from schemas import (
    MethodologyExtractRequest, MethodologyExtractResponse,
    MethodologySaveRequest, MethodologyOut, MethodologyData,
)
from services import methodology_service

from schemas import (
    ScopingParseRequest, ScopingSynthesizeRequest,
    ScopingSaveRequest, ScopingSessionOut, ScopingListResponse,
)
from services import scoping_service

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
    BuildQueryRequest, BuildQueryResponse,
    SearchRequest, SearchResponse, PaperResult,
    SavePaperRequest,      
)
from services.ai_service import get_chat_response
from services.deepgram_service import transcribe_audio
from services.rag_service import index_pdf, ask_document, index_text


# ============================================================
# STEP 3: App + middleware
# ============================================================
app = FastAPI(title="Orbirag API", version="0.2.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
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



# ============================================================
# Paper Orbit (RAG) — Paste / Type Text
# ============================================================

class TextIngestRequest(BaseModel):
    text: str
    title: Optional[str] = "Pasted Text"
    user_id: Optional[str] = "anonymous"


@app.post(
    "/api/ai/ingest-text",
    response_model=UploadPdfResponse,
    tags=["Paper Orbit"],
)
async def ingest_text_route(req: TextIngestRequest):
    """
    Index raw pasted/typed text into the vector store so it can be
    queried later by /api/ai/chat-with-pdf.
    """
    text = (req.text or "").strip()
    if not text:
        raise HTTPException(400, "Text is empty")
    if len(text) > 100_000:
        raise HTTPException(413, "Text too large (max 100,000 chars)")

    try:
        result = index_text(text, req.title or "Pasted Text", req.user_id or "anonymous")
        return UploadPdfResponse(
            doc_id=result["doc_id"],
            filename=req.title or "Pasted Text",
            num_chunks=result["num_chunks"],
            num_pages=1,
            message="Text indexed successfully",
        )
    except Exception as e:
        print(f"[RAG] ingest-text error: {type(e).__name__}: {e}")
        raise HTTPException(500, f"Failed to index text: {e}")


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
# Literature Retrieval — Step 1: Build Query
# ============================================================
@app.post(
    "/api/ai/build-search",
    response_model=BuildQueryResponse,
    tags=["Literature"],
)
async def build_search_route(req: BuildQueryRequest):
    """Extract keywords + synonyms + Boolean query from a topic."""
    print(f"[Literature] build-search for topic: {req.topic[:80]}")
    result = await build_search_query(req.topic)
    if not result:
        raise HTTPException(500, "Could not build search query")

    return BuildQueryResponse(
        keywords=result.get("keywords", []),
        synonyms=result.get("synonyms", []),
        boolean_query=result.get("boolean_query", ""),
    )


# ============================================================
# Literature Retrieval — Step 2: Search
# ============================================================
@app.post(
    "/api/search",
    response_model=SearchResponse,
    tags=["Literature"],
)
async def search_route(req: SearchRequest):
    """
    Search Semantic Scholar → summarize each result with Gemini.
    Runs summaries in parallel for speed.
    """
    print(f"[Literature] search: query='{req.query[:80]}', limit={req.limit}")

    try:
        papers = await search_semantic_scholar(
            query=req.query,
            limit=req.limit or 10,
            year_range=req.date_range,
            discipline=req.discipline,
        )
    except RuntimeError as e:
        raise HTTPException(429, str(e))
    except Exception as e:
        raise HTTPException(500, f"Search failed: {e}")

    if not papers:
        return SearchResponse(results=[], count=0)

    # Summarize in parallel
    try:
        summaries = await asyncio.gather(
            *[summarize_paper(p["title"], p["abstract"]) for p in papers],
            return_exceptions=True,
        )
    except Exception as e:
        print(f"[Literature] summarize error: {e}")
        summaries = ["No summary available."] * len(papers)

    results = []
    for p, s in zip(papers, summaries):
        if isinstance(s, Exception):
            s = "No summary available."
        results.append(
            PaperResult(**p, ai_summary=s)
        )

    print(f"[Literature] returning {len(results)} results")
    return SearchResponse(results=results, count=len(results))


# ============================================================
# Literature Retrieval — Step 3: Save Paper
# ============================================================
@app.post("/api/save-paper", tags=["Literature"])
async def save_paper_route(req: SavePaperRequest):
    """Save a paper to the user's library (Postgres). Returns {success, id}."""
    try:
        from database import SessionLocal
        from db_queries import save_paper, upsert_user
        db = SessionLocal()
        try:
            upsert_user(db, firebase_uid="anonymous", display_name="Anonymous")
            row = save_paper(
                db,
                user_id="anonymous",
                data={
                    "title": req.title,
                    "authors": req.authors or "",
                    "year": str(req.year or ""),
                    "source": req.source or "Semantic Scholar",
                    "citations": req.citations or 0,
                    "journal": req.venue or "",
                    "abstract": req.abstract or "",
                    "url": req.url or "",
                },
            )
            return {"success": True, "id": str(row.id)}
        finally:
            db.close()
    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"[Literature] save-paper error: {e}")
        raise HTTPException(500, f"Save failed: {e}")


# ============================================================
# Papers Library — list / delete / update progress
# ============================================================
from pydantic import BaseModel as _BaseModel

class _ProgressUpdate(_BaseModel):
    status: Optional[str] = None   # unread | reading | analyzed | read
    progress: Optional[float] = None  # 0.0 – 1.0


@app.get("/api/papers", tags=["Literature"])
def list_papers_route(user_id: str = "anonymous", db: Session = Depends(get_db)):
    """List saved papers for a user."""
    from db_queries import list_papers
    rows = list_papers(db, user_id=user_id)
    return {"items": [
        {
            "id": str(r.id),
            "title": r.title or "",
            "authors": r.authors or "",
            "year": r.year or "",
            "journal": r.journal or "",
            "abstract": r.abstract or "",
            "url": r.url or "",
            "source": r.source or "Semantic Scholar",
            "status": r.status or "unread",
            "progress": float(r.progress or 0.0),
            "is_favorite": bool(r.is_favorite),
        }
        for r in rows
    ]}


@app.delete("/api/papers/{paper_id}", tags=["Literature"])
def delete_paper_route(paper_id: UUID, db: Session = Depends(get_db)):
    """Delete a saved paper."""
    from db_queries import delete_paper
    if not delete_paper(db, paper_id=str(paper_id), user_id="anonymous"):
        raise HTTPException(404, "Paper not found")
    return {"success": True}


@app.patch("/api/papers/{paper_id}", tags=["Literature"])
def update_paper_route(paper_id: UUID, payload: _ProgressUpdate, db: Session = Depends(get_db)):
    """Update reading status and/or progress for a saved paper."""
    from db_queries import update_paper_status
    row = update_paper_status(
        db,
        paper_id=str(paper_id),
        user_id="anonymous",
        status=payload.status,
        progress=payload.progress,
    )
    if not row:
        raise HTTPException(404, "Paper not found")
    return {"success": True}


# ============================================================
# Literature Retrieval — Step 4: Recommendations
# ============================================================
@app.get(
    "/api/recommendations",
    response_model=SearchResponse,
    tags=["Literature"],
)
async def recommendations_route(
    user_id: str = "anonymous",
    limit: int = 5,
):
    """
    Get paper recommendations based on user's recent search or saved papers.
    """
    topic = None
    try:
        from database import SessionLocal
        from db_queries import list_searches, list_papers
        db = SessionLocal()
        try:
            searches = list_searches(db, user_id=user_id, limit=1)
            if searches and searches[0].topic:
                topic = searches[0].topic
            else:
                papers = list_papers(db, user_id=user_id)
                if papers and papers[0].title:
                    topic = papers[0].title
        finally:
            db.close()
    except Exception as e:
        print(f"[Recommendations] DB lookup error: {e}")

    if not topic:
        topic = "artificial intelligence machine learning"

    print(f"[Recommendations] query='{topic}', limit={limit}")
    try:
        papers = await search_semantic_scholar(query=topic, limit=limit)
    except Exception as e:
        print(f"[Recommendations] search error: {e}")
        papers = []

    results = [PaperResult(**p) for p in papers]
    return SearchResponse(results=results, count=len(results))


# ============================================================
# Citations
# ============================================================
from pydantic import BaseModel, Field
from typing import Optional


class SaveCitationRequest(BaseModel):
    title: str
    authors: Optional[str] = ""
    year: Optional[str] = ""
    journal: Optional[str] = ""
    source_type: Optional[str] = ""
    style: Optional[str] = ""
    in_text: Optional[str] = ""
    reference_list: Optional[str] = ""


@app.post("/api/citations/save", tags=["Citations"])
async def save_citation_route(
    req: SaveCitationRequest,
    user_id: str = "anonymous",
):
    """Save a citation to the user's library (Postgres)."""
    print(f"[Citation] save: {req.title[:80]}")

    try:
        from database import SessionLocal
        from db_queries import save_citation, upsert_user

        db = SessionLocal()
        try:
            # Ensure the user row exists
            upsert_user(db, firebase_uid=user_id, display_name="Anonymous")

            save_citation(
                db,
                user_id=user_id,
                data={
                    "title": req.title,
                    "authors": req.authors,
                    "year": req.year,
                    "journal": req.journal,
                    "style": req.style,
                    "source_type": req.source_type,
                    "in_text": req.in_text,
                    "reference_list": req.reference_list,
                },
            )
            return {"success": True}
        finally:
            db.close()
    except Exception as e:
        print(f"[Citation] save error: {e}")
        raise HTTPException(500, f"Save failed: {e}")


@app.get("/api/citations", tags=["Citations"])
async def list_citations_route(user_id: str = "anonymous"):
    """List all citations for a user."""
    print(f"[Citation] list for user={user_id}")

    try:
        from database import SessionLocal
        from db_queries import list_citations

        db = SessionLocal()
        try:
            rows = list_citations(db, user_id=user_id)
            return {
                "citations": [
                    {
                        "id": r.id,
                        "title": r.title,
                        "authors": r.authors,
                        "year": r.year,
                        "journal": r.journal,
                        "source_type": r.source_type,
                        "style": r.style,
                        "in_text": r.in_text,
                        "reference_list": r.reference_list,
                        "created_at": r.created_at.isoformat() if r.created_at else None,
                    }
                    for r in rows
                ]
            }
        finally:
            db.close()
    except Exception as e:
        print(f"[Citation] list error: {e}")
        raise HTTPException(500, f"List failed: {e}")


@app.delete("/api/citations/{citation_id}", tags=["Citations"])
async def delete_citation_route(citation_id: str, user_id: str = "anonymous"):
    """Delete a citation."""
    print(f"[Citation] delete id={citation_id}")

    try:
        from database import SessionLocal
        from db_queries import delete_citation

        db = SessionLocal()
        try:
            ok = delete_citation(db, citation_id=citation_id, user_id=user_id)
            if not ok:
                raise HTTPException(404, "Citation not found")
            return {"success": True}
        finally:
            db.close()
    except HTTPException:
        raise
    except Exception as e:
        print(f"[Citation] delete error: {e}")
        raise HTTPException(500, f"Delete failed: {e}")

# ============================================================
# Library
# ============================================================
@app.post("/api/library/items", response_model=LibraryItemOut, tags=["Library"])
def create_library_item(payload: LibraryItemCreate, db: Session = Depends(get_db)):
    return library_service.create_item(db, payload)


@app.get("/api/library/items", response_model=LibraryListResponse, tags=["Library"])
def list_library_items(
    user_id: str | None = None,
    search: str | None = None,
    db: Session = Depends(get_db),
):
    items = library_service.list_items(db, user_id=user_id, search=search)
    return LibraryListResponse(items=items, count=len(items))


@app.patch("/api/library/items/{item_id}", response_model=LibraryItemOut, tags=["Library"])
def update_library_item(
    item_id: UUID,
    payload: LibraryItemUpdate,
    db: Session = Depends(get_db),
):
    item = library_service.update_item(db, item_id, payload)
    if not item:
        raise HTTPException(404, "Item not found")
    return item


@app.patch("/api/library/items/{item_id}/pin", response_model=LibraryItemOut, tags=["Library"])
def toggle_library_pin(item_id: UUID, db: Session = Depends(get_db)):
    item = library_service.toggle_pin(db, item_id)
    if not item:
        raise HTTPException(404, "Item not found")
    return item


@app.delete("/api/library/items/{item_id}", tags=["Library"])
def delete_library_item(item_id: UUID, db: Session = Depends(get_db)):
    ok = library_service.delete_item(db, item_id)
    if not ok:
        raise HTTPException(404, "Item not found")
    return {"deleted": True}

# ============================================================
# Notes
# ============================================================
@app.post("/api/notes/items", response_model=NoteOut, tags=["Notes"])
def create_note(payload: NoteCreate, db: Session = Depends(get_db)):
    return notes_service.create_note(db, payload)


@app.get("/api/notes/items", response_model=NoteListResponse, tags=["Notes"])
def list_notes(
    user_id: str | None = None,
    search: str | None = None,
    db: Session = Depends(get_db),
):
    items = notes_service.list_notes(db, user_id=user_id, search=search)
    return NoteListResponse(items=items, count=len(items))


@app.patch("/api/notes/items/{note_id}", response_model=NoteOut, tags=["Notes"])
def update_note(
    note_id: UUID,
    payload: NoteUpdate,
    db: Session = Depends(get_db),
):
    note = notes_service.update_note(db, note_id, payload)
    if not note:
        raise HTTPException(404, "Note not found")
    return note


@app.patch("/api/notes/items/{note_id}/pin", response_model=NoteOut, tags=["Notes"])
def toggle_note_pin(note_id: UUID, db: Session = Depends(get_db)):
    note = notes_service.toggle_pin(db, note_id)
    if not note:
        raise HTTPException(404, "Note not found")
    return note


@app.delete("/api/notes/items/{note_id}", tags=["Notes"])
def delete_note(note_id: UUID, db: Session = Depends(get_db)):
    ok = notes_service.delete_note(db, note_id)
    if not ok:
        raise HTTPException(404, "Note not found")
    return {"deleted": True}

# ============================================================
# Auth
# ============================================================
@app.post("/api/auth/login", response_model=LoginResponse, tags=["Auth"])
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = user_service.get_by_username(db, payload.username)
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(401, "Invalid username or password")
    if not user.is_active:
        raise HTTPException(403, "Account is disabled")

    user.last_login = datetime.now(timezone.utc)
    db.commit()
    db.refresh(user)

    token = create_access_token(str(user.id), user.role)
    return LoginResponse(access_token=token, user=user)


@app.get("/api/auth/me", response_model=UserOut, tags=["Auth"])
def me(current: User = Depends(get_current_user)):
    return current


@app.patch("/api/auth/avatar", response_model=UserOut, tags=["Auth"])
def update_my_avatar(
    payload: AvatarUpdateRequest,
    current: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user = user_service.set_avatar(db, current.id, payload.avatar_base64)
    if not user:
        raise HTTPException(404, "User not found")
    return user


# ============================================================
# Admin — users
# ============================================================
@app.get("/api/admin/users", response_model=UserListResponse, tags=["Admin"])
def admin_list_users(
    search: str | None = None,
    _: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    users = user_service.list_users(db, search=search)
    return UserListResponse(items=users, count=len(users))


@app.post("/api/admin/users", response_model=UserOut, tags=["Admin"])
def admin_create_user(
    payload: UserCreate,
    _: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    if user_service.get_by_username(db, payload.username):
        raise HTTPException(409, "Username already exists")
    return user_service.create_user(db, payload)


@app.patch("/api/admin/users/{user_id}/ban", response_model=UserOut, tags=["Admin"])
def admin_ban_user(
    user_id: UUID,
    _: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    user = user_service.set_active(db, user_id, False)
    if not user:
        raise HTTPException(404, "User not found")
    return user


@app.patch("/api/admin/users/{user_id}/unban", response_model=UserOut, tags=["Admin"])
def admin_unban_user(
    user_id: UUID,
    _: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    user = user_service.set_active(db, user_id, True)
    if not user:
        raise HTTPException(404, "User not found")
    return user


@app.patch("/api/admin/users/{user_id}/role", response_model=UserOut, tags=["Admin"])
def admin_set_role(
    user_id: UUID,
    role: str,
    _: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    if role not in ("user", "admin"):
        raise HTTPException(400, "Invalid role")
    user = user_service.set_role(db, user_id, role)
    if not user:
        raise HTTPException(404, "User not found")
    return user


@app.patch("/api/admin/users/{user_id}/password", response_model=UserOut, tags=["Admin"])
def admin_reset_password(
    user_id: UUID,
    payload: AdminPasswordResetRequest,
    _: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    user = user_service.reset_password(db, user_id, payload.new_password)
    if not user:
        raise HTTPException(404, "User not found")
    return user


@app.get("/api/admin/users/{user_id}", response_model=UserOut, tags=["Admin"])
def admin_get_user(
    user_id: UUID,
    _: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    user = user_service.get_by_id(db, user_id)
    if not user:
        raise HTTPException(404, "User not found")
    return user


@app.delete("/api/admin/users/{user_id}", tags=["Admin"])
def admin_delete_user(
    user_id: UUID,
    _: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    if not user_service.delete_user(db, user_id):
        raise HTTPException(404, "User not found")
    return {"deleted": True}

# ============================================================
# Plagiarism
# ============================================================
@app.post("/api/plagiarism/check", response_model=PlagiarismCheckResponse, tags=["Plagiarism"])
async def plagiarism_check(payload: PlagiarismCheckRequest, db: Session = Depends(get_db)):
    try:
        result = await plagiarism_service.analyze_text(payload.text)
        row = plagiarism_service.save_check(
            db,
            text=payload.text,
            similarity_score=result["similarity_score"],
            matches=result["matches"],
            user_id=payload.user_id,
        )
        return PlagiarismCheckResponse(
            id=row.id,
            similarity_score=row.similarity_score,
            matches=row.matches,
            created_at=row.created_at,
        )
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"{type(e).__name__}: {e}")

@app.post("/api/plagiarism/paraphrase", response_model=RewriteResponse, tags=["Plagiarism"])
async def plagiarism_paraphrase(payload: RewriteRequest):
    result = await plagiarism_service.rewrite_text(payload.text, "paraphrase")
    return RewriteResponse(result=result)


@app.post("/api/plagiarism/humanize", response_model=RewriteResponse, tags=["Plagiarism"])
async def plagiarism_humanize(payload: RewriteRequest):
    result = await plagiarism_service.rewrite_text(payload.text, "humanize")
    return RewriteResponse(result=result)


@app.post("/api/plagiarism/cite", response_model=CitationResponse, tags=["Plagiarism"])
def plagiarism_cite(payload: CitationRequest):
    citation = plagiarism_service.format_citation(
        payload.source, payload.year, payload.style
    )
    return CitationResponse(citation=citation)


@app.get("/api/plagiarism/history", tags=["Plagiarism"])
def plagiarism_history(user_id: str | None = None, db: Session = Depends(get_db)):
    rows = plagiarism_service.list_checks(db, user_id=user_id)
    return {"items": [
        {
            "id": str(r.id),
            "similarity_score": r.similarity_score,
            "matches_count": len(r.matches or []),
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in rows
    ]}


@app.delete("/api/plagiarism/{check_id}", tags=["Plagiarism"])
def plagiarism_delete(check_id: UUID, db: Session = Depends(get_db)):
    if not plagiarism_service.delete_check(db, check_id):
        raise HTTPException(404, "Check not found")
    return {"deleted": True}

#citation generation endpoints
# ---------- Generate from URL or Manual ----------
@app.post("/api/citations/generate", response_model=CitationGenerateResponse, tags=["Citations"])
async def generate_citation(req: CitationGenerateRequest):
    """
    Generate a citation from:
      - source="url"    → uses req.url
      - source="manual" → uses req.metadata
    """
    try:
        if req.source == "url":
            if not req.url:
                raise HTTPException(400, "url is required when source='url'")
            result = await citation_service.generate(
                style=req.style,
                url=req.url,
            )
        elif req.source == "manual":
            if not req.metadata:
                raise HTTPException(400, "metadata is required when source='manual'")
            result = await citation_service.generate(
                style=req.style,
                metadata=req.metadata.model_dump(),
            )
        else:
            raise HTTPException(400, "Use /generate-pdf for PDF source")

        return CitationGenerateResponse(**result)
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(400, detail=str(e))
    except Exception as e:
        raise HTTPException(500, detail=f"Citation generation failed: {e}")


# ---------- Generate from PDF upload ----------
@app.post("/api/citations/generate-pdf", response_model=CitationGenerateResponse, tags=["Citations"])
async def generate_citation_from_pdf(
    file: UploadFile = File(...),
    style: str = Form("APA 7"),
):
    """Extract text from an uploaded PDF and produce a citation."""
    if not file.filename.lower().endswith(".pdf"):
        raise HTTPException(400, "Only PDF files are supported")

    pdf_bytes = await file.read()
    if len(pdf_bytes) > 20 * 1024 * 1024:
        raise HTTPException(413, "PDF too large (max 20 MB)")

    text = citation_service.extract_text_from_pdf(pdf_bytes)
    if not text.strip():
        raise HTTPException(400, "Could not extract text from PDF")

    result = await citation_service.generate(style=style, raw_text=text)
    return CitationGenerateResponse(**result)

# ============================================================
# Methodology
# ============================================================
@app.post("/api/methodology/extract",
          response_model=MethodologyExtractResponse,
          tags=["Methodology"])
async def methodology_extract(req: MethodologyExtractRequest):
    data = await methodology_service.extract(req.text)
    return MethodologyExtractResponse(data=MethodologyData(**data))


@app.post("/api/methodology/save",
          response_model=MethodologyOut,
          tags=["Methodology"])
def methodology_save(req: MethodologySaveRequest, db: Session = Depends(get_db)):
    row = methodology_service.save(
        db,
        raw_text=req.raw_text or req.data.raw_highlighted_text,
        data=req.data.model_dump(),
        paper_title=req.paper_title,
        user_id=req.user_id,
    )
    return MethodologyOut(
        id=row.id,
        paper_title=row.paper_title,
        raw_text=row.raw_text,
        data=MethodologyData(**methodology_service.to_data_dict(row)),
        created_at=row.created_at,
    )


@app.get("/api/methodology/history", tags=["Methodology"])
def methodology_history(user_id: str | None = None, db: Session = Depends(get_db)):
    rows = methodology_service.list_all(db, user_id=user_id)
    return {"items": [
        {
            "id": str(r.id),
            "paper_title": r.paper_title,
            "summary": r.summary,
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in rows
    ]}


@app.delete("/api/methodology/{m_id}", tags=["Methodology"])
def methodology_delete(m_id: UUID, db: Session = Depends(get_db)):
    if not methodology_service.delete(db, m_id):
        raise HTTPException(404, "Methodology not found")
    return {"deleted": True}

# ============================================================
# Guided Topic Scoping
# ============================================================
@app.post("/api/scoping/parse", tags=["Scoping"])
async def scoping_parse(req: ScopingParseRequest):
    try:
        data = await scoping_service.parse_topic(req.topic)
        return data
    except Exception as e:
        print(f"[Scoping] parse error: {type(e).__name__}: {e}")
        raise HTTPException(500, f"Parse failed: {e}")


@app.post("/api/scoping/synthesize", tags=["Scoping"])
async def scoping_synthesize(req: ScopingSynthesizeRequest):
    try:
        question = await scoping_service.synthesize_question(
            req.model_dump(),
            regenerate=req.regenerate,
        )
        return {**req.model_dump(), "research_question": question}
    except ValueError as e:
        raise HTTPException(422, str(e))
    except Exception as e:
        print(f"[Scoping] synthesize error: {type(e).__name__}: {e}")
        raise HTTPException(500, f"Synthesize failed: {e}")


@app.post("/api/scoping/sessions", response_model=ScopingSessionOut, tags=["Scoping"])
def scoping_save(req: ScopingSaveRequest, db: Session = Depends(get_db)):
    row = scoping_service.save_session(db, req.model_dump(), user_id=req.user_id)
    return ScopingSessionOut(**scoping_service.to_dict(row))


@app.get("/api/scoping/sessions", response_model=ScopingListResponse, tags=["Scoping"])
def scoping_list(user_id: str | None = None, db: Session = Depends(get_db)):
    rows = scoping_service.list_sessions(db, user_id=user_id)
    items = [ScopingSessionOut(**scoping_service.to_dict(r)) for r in rows]
    return ScopingListResponse(items=items, count=len(items))