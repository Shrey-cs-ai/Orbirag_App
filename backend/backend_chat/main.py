"""
Orbirag Chat Backend — Ori chatbot + PDF chat + voice transcription + text analysis.
"""

import os
from pathlib import Path
from dotenv import load_dotenv
from fastapi import FastAPI, UploadFile, File, HTTPException, Form, Header, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List

try:
    from backend_research.database import SessionLocal as ResearchSessionLocal
    from backend_research.services import chat_history_service
except Exception as e:
    print(f"[ChatMain] Research DB import notice: {e}")
    ResearchSessionLocal = None
    chat_history_service = None

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


try:
    from backend_chat.models import (
        ChatRequest, ChatResponse,
        TranscribeResponse,
        PdfChatRequest, PdfChatResponse,
        PdfUploadResponse,
        AnalyzeRequest, AnalyzeResponse, TextStats, Suggestion,
    )
    from backend_chat.services.ai_service import (
        get_chat_response, get_paper_response, get_suggestions, _generate_with_fallback
    )
    from backend_chat.services.deepgram_service import transcribe_audio
    from backend_chat.services.pdf_service import (
        extract_text_from_pdf,
        chunk_text,
        save_paper,
        get_paper,
        find_relevant_chunks,
    )
    from backend_chat.services.word_counter_service import build_stats
except ImportError:
    from models import (
        ChatRequest, ChatResponse,
        TranscribeResponse,
        PdfChatRequest, PdfChatResponse,
        PdfUploadResponse,
        AnalyzeRequest, AnalyzeResponse, TextStats, Suggestion,
    )
    from services.ai_service import (
        get_chat_response, get_paper_response, get_suggestions, _generate_with_fallback
    )
    from services.deepgram_service import transcribe_audio
    from services.pdf_service import (
        extract_text_from_pdf,
        chunk_text,
        save_paper,
        get_paper,
        find_relevant_chunks,
    )
    from services.word_counter_service import build_stats


app = FastAPI(title="Orbirag Chat API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _validate_file_size(data: bytes, max_mb: int):
    if len(data) == 0:
        raise HTTPException(status_code=400, detail="Empty file")
    if len(data) > max_mb * 1024 * 1024:
        raise HTTPException(status_code=413, detail=f"File too large (max {max_mb} MB)")


def _to_history_dicts(messages):
    return [{"role": getattr(m, "role", "user"), "content": getattr(m, "content", "")} for m in (messages or [])]


@app.get("/", tags=["Health"])
def root():
    return {"message": "Orbirag Chat API is running"}


# Ori Chatbot
@app.post("/chat", response_model=ChatResponse, tags=["Chat"])
@app.post("/api/chat", response_model=ChatResponse, tags=["Chat"])
async def chat(request: ChatRequest):
    history_dicts = _to_history_dicts(request.history)
    response = await get_chat_response(request.message, history_dicts)

    conv_id = request.conversation_id
    if ResearchSessionLocal and chat_history_service:
        db = ResearchSessionLocal()
        try:
            conv, _, _ = chat_history_service.record_chat_turn(
                db,
                user_message=request.message,
                assistant_message=response,
                session_type="ori_chat",
                conversation_id=conv_id,
                user_id=request.user_id,
            )
            conv_id = str(conv.id)
        except Exception as e:
            print(f"[ChatMain] History record warning: {e}")
        finally:
            db.close()

    return ChatResponse(response=response, conversation_id=conv_id)


# Voice
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


# Paper Orbit: Upload PDF
@app.post("/api/ai/upload-pdf", response_model=PdfUploadResponse, tags=["Paper Orbit"])
@app.post("/upload-pdf", response_model=PdfUploadResponse, tags=["Paper Orbit"])
async def upload_pdf(
    file: UploadFile = File(...),
    user_id: Optional[str] = Form(None),
    x_user_id: Optional[str] = Header(None, alias="x-user-id"),
):
    if file.content_type not in {"application/pdf", "application/octet-stream"} and not (file.filename and file.filename.lower().endswith(".pdf")):
        raise HTTPException(400, f"Only PDF files allowed. Got: {file.content_type}")

    pdf_bytes = await file.read()
    _validate_file_size(pdf_bytes, max_mb=20)

    try:
        pages = extract_text_from_pdf(pdf_bytes)
        if not pages:
            raise HTTPException(400, "Could not extract text from PDF")

        effective_user_id = user_id or x_user_id
        chunks = chunk_text(pages, chunk_size=800, overlap=100)
        paper_id = save_paper(
            file.filename or "untitled.pdf",
            chunks,
            user_id=effective_user_id,
            num_pages=len(pages),
        )

        return PdfUploadResponse(
            paper_id=paper_id,
            doc_id=paper_id,
            filename=file.filename or "untitled.pdf",
            chunk_count=len(chunks),
            num_chunks=len(chunks),
            num_pages=len(pages),
        )
    except HTTPException:
        raise
    except Exception as e:
        print(f"[PDF] Upload error: {type(e).__name__}: {e}")
        raise HTTPException(500, f"Upload failed: {e}")


# Paper Orbit: Chat with PDF
@app.post("/api/ai/chat-with-pdf", response_model=PdfChatResponse, tags=["Paper Orbit"])
@app.post("/chat-with-pdf", response_model=PdfChatResponse, tags=["Paper Orbit"])
async def chat_with_pdf(
    request: PdfChatRequest,
    x_user_id: Optional[str] = Header(None, alias="x-user-id"),
):
    paper_id = request.paper_id or request.doc_id
    question = request.question or request.message
    if not paper_id:
        raise HTTPException(400, "paper_id or doc_id is required")
    if not question:
        raise HTTPException(400, "question or message is required")

    effective_user_id = request.user_id or x_user_id
    paper = get_paper(paper_id, user_id=effective_user_id)
    if isinstance(paper, dict) and paper.get("error") == "unauthorized":
        raise HTTPException(403, "You do not have permission to access this PDF")
    if not paper:
        raise HTTPException(404, "Paper not found")

    top_k = request.top_k or 3
    relevant = find_relevant_chunks(question, paper["chunks"], top_k=top_k)

    if not relevant:
        return PdfChatResponse(
            response="I couldn't find relevant information in this paper.",
            sources=[],
            conversation_id=request.conversation_id,
        )

    context = "\n\n".join(f"[Page {c['page']}]\n{c['text']}" for c in relevant)

    response = await get_paper_response(
        question=question,
        context=context,
        history=_to_history_dicts(request.history),
    )

    conv_id = request.conversation_id
    if ResearchSessionLocal and chat_history_service:
        db = ResearchSessionLocal()
        try:
            conv, _, _ = chat_history_service.record_chat_turn(
                db,
                user_message=question,
                assistant_message=response,
                session_type="paper_orbit",
                conversation_id=conv_id,
                user_id=effective_user_id,
                paper_id=None,
                sources=relevant,
            )
            conv_id = str(conv.id)
        except Exception as e:
            print(f"[ChatMain] History record warning for PDF: {e}")
        finally:
            db.close()

    return PdfChatResponse(response=response, sources=relevant, conversation_id=conv_id)


# AI Rewrite (Paraphrase / Humanize)
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
    """Paraphrase or humanize a piece of text using Groq/Gemini."""
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


# ---- Chat History Endpoints ----
@app.get("/api/chat/history", tags=["Chat History"])
def get_chat_history_route(
    session_type: Optional[str] = Query(None),
    user_id: Optional[str] = Query(None),
    x_user_id: Optional[str] = Header(None, alias="x-user-id"),
):
    effective_user_id = user_id or x_user_id
    if not (ResearchSessionLocal and chat_history_service):
        return {"conversations": [], "total": 0}

    db = ResearchSessionLocal()
    try:
        conversations = chat_history_service.list_conversations(
            db,
            user_id=effective_user_id,
            session_type=session_type,
        )
        return {"conversations": conversations, "total": len(conversations)}
    finally:
        db.close()


@app.get("/api/chat/history/{conversation_id}", tags=["Chat History"])
def get_conversation_detail_route(
    conversation_id: str,
    user_id: Optional[str] = Query(None),
    x_user_id: Optional[str] = Header(None, alias="x-user-id"),
):
    effective_user_id = user_id or x_user_id
    if not (ResearchSessionLocal and chat_history_service):
        raise HTTPException(status_code=404, detail="Conversation not found")

    db = ResearchSessionLocal()
    try:
        conv = chat_history_service.get_conversation(
            db,
            conversation_id=conversation_id,
            user_id=effective_user_id,
        )
        if not conv:
            raise HTTPException(status_code=404, detail="Conversation not found")
        return conv
    finally:
        db.close()


@app.delete("/api/chat/history/{conversation_id}", tags=["Chat History"])
def delete_conversation_route(
    conversation_id: str,
    user_id: Optional[str] = Query(None),
    x_user_id: Optional[str] = Header(None, alias="x-user-id"),
):
    effective_user_id = user_id or x_user_id
    if not (ResearchSessionLocal and chat_history_service):
        raise HTTPException(status_code=404, detail="Conversation not found")

    db = ResearchSessionLocal()
    try:
        success = chat_history_service.delete_conversation(
            db,
            conversation_id=conversation_id,
            user_id=effective_user_id,
        )
        if not success:
            raise HTTPException(status_code=404, detail="Conversation not found")
        return {"deleted": True, "conversation_id": conversation_id}
    finally:
        db.close()

