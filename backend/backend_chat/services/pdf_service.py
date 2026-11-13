import io
import re
import uuid
from typing import Dict, List

from pypdf import PdfReader


from datetime import datetime
try:
    from backend_chat.database import ChatPdfDocument, SessionLocal, init_db
except ImportError:
    from database import ChatPdfDocument, SessionLocal, init_db

# Transient fallback cache if DB is temporarily unreachable or empty
_fallback_cache: Dict[str, dict] = {}


# Extract text from PDF
def extract_text_from_pdf(pdf_bytes: bytes) -> List[dict]:
    """Extract text from each page of the PDF."""
    reader = PdfReader(io.BytesIO(pdf_bytes))
    pages = []

    for page_num, page in enumerate(reader.pages, start=1):
        text = page.extract_text() or ""
        text = text.strip()
        if text:
            pages.append({"text": text, "page": page_num})

    return pages


# Chunk long text into smaller pieces
def chunk_text(
    pages: List[dict],
    chunk_size: int = 800,
    overlap: int = 100,
) -> List[dict]:
    """Split each page's text into overlapping chunks."""
    chunks = []

    for page in pages:
        text = page["text"]
        page_num = page["page"]

        if len(text) <= chunk_size:
            chunks.append({"text": text, "page": page_num})
            continue

        start = 0
        while start < len(text):
            end = start + chunk_size
            chunk = text[start:end].strip()
            if chunk:
                chunks.append({"text": chunk, "page": page_num})
            if end >= len(text):
                break
            start = end - overlap

    return chunks


# Store and retrieve papers (database backed with max 20 PDFs per user)
def save_paper(
    filename: str,
    chunks: List[dict],
    user_id: str | None = None,
    num_pages: int = 1,
) -> str:
    """Store a paper in ChatPdfDocument, maintaining a max of 20 PDFs per user."""
    paper_id = str(uuid.uuid4())
    db = SessionLocal()
    try:
        init_db()
        # Enforce max 20 PDFs limit per user
        if user_id:
            existing_docs = (
                db.query(ChatPdfDocument)
                .filter(ChatPdfDocument.user_id == user_id)
                .order_by(ChatPdfDocument.created_at.asc())
                .all()
            )
            if len(existing_docs) >= 20:
                excess = len(existing_docs) - 19
                for old_doc in existing_docs[:excess]:
                    db.delete(old_doc)
                db.flush()

        doc = ChatPdfDocument(
            id=paper_id,
            user_id=user_id,
            filename=filename,
            chunks=chunks,
            num_pages=num_pages,
            created_at=datetime.utcnow(),
        )
        db.add(doc)
        db.commit()
        print(f"[PDF] Saved paper {paper_id} ({filename}) for user={user_id} with {len(chunks)} chunks")
    except Exception as e:
        db.rollback()
        print(f"[PDF] Warning: DB save failed ({e}), using fallback cache.")
        _fallback_cache[paper_id] = {
            "id": paper_id,
            "filename": filename,
            "chunks": chunks,
            "num_pages": num_pages,
            "user_id": user_id,
        }
    finally:
        db.close()

    # Also keep a copy in fallback cache for seamless fallback
    _fallback_cache[paper_id] = {
        "id": paper_id,
        "filename": filename,
        "chunks": chunks,
        "num_pages": num_pages,
        "user_id": user_id,
    }
    return paper_id


def get_paper(paper_id: str, user_id: str | None = None) -> dict | None:
    """Retrieve paper by paper_id and optionally enforce user_id privacy."""
    db = SessionLocal()
    try:
        init_db()
        doc = db.query(ChatPdfDocument).filter(ChatPdfDocument.id == paper_id).first()
        if not doc:
            # Check fallback cache
            cached = _fallback_cache.get(paper_id)
            if not cached:
                return None
            if user_id and cached.get("user_id") and cached.get("user_id") != user_id:
                return {"error": "unauthorized"}
            return cached

        # Check authorization
        if user_id and doc.user_id and doc.user_id != user_id:
            return {"error": "unauthorized"}

        return {
            "id": doc.id,
            "filename": doc.filename,
            "chunks": doc.chunks,
            "num_pages": doc.num_pages,
            "user_id": doc.user_id,
        }
    except Exception as e:
        print(f"[PDF] Warning: DB fetch failed ({e}), checking fallback cache.")
        cached = _fallback_cache.get(paper_id)
        if not cached:
            return None
        if user_id and cached.get("user_id") and cached.get("user_id") != user_id:
            return {"error": "unauthorized"}
        return cached
    finally:
        db.close()


def get_all_papers(user_id: str | None = None) -> Dict[str, dict]:
    """Retrieve all papers, optionally filtered by user_id."""
    db = SessionLocal()
    try:
        init_db()
        query = db.query(ChatPdfDocument)
        if user_id:
            query = query.filter(ChatPdfDocument.user_id == user_id)
        docs = query.all()
        result = {}
        for doc in docs:
            result[doc.id] = {
                "id": doc.id,
                "filename": doc.filename,
                "chunks": doc.chunks,
                "num_pages": doc.num_pages,
                "user_id": doc.user_id,
            }
        return result
    except Exception as e:
        print(f"[PDF] DB get_all_papers error: {e}")
        return _fallback_cache
    finally:
        db.close()


# Find relevant chunks for a question
def find_relevant_chunks(
    question: str,
    chunks: List[dict],
    top_k: int = 3,
) -> List[dict]:
    """Keyword + phrase scoring for relevance."""
    if not chunks:
        return []

    # Clean and tokenize question
    q_clean = re.sub(r'[^\w\s]', ' ', question.lower())
    q_words = [w for w in q_clean.split() if len(w) > 2]

    stopwords = {
        'the', 'and', 'for', 'are', 'but', 'not', 'you', 'all', 'can',
        'her', 'was', 'one', 'our', 'out', 'day', 'get', 'has', 'him',
        'his', 'how', 'its', 'new', 'now', 'old', 'see', 'two', 'who',
        'why', 'this', 'that', 'with', 'from', 'what', 'when', 'where',
        'which', 'while', 'about', 'main', 'topic', 'paper', 'study',
    }
    q_words = [w for w in q_words if w not in stopwords]

    if not q_words:
        mid = len(chunks) // 2
        return chunks[max(0, mid - 1):mid + 2][:top_k]

    scored = []
    for chunk in chunks:
        text_lower = chunk["text"].lower()

        score = 0
        for w in q_words:
            if w in text_lower:
                score += len(w)

        for w in q_words:
            if len(w) > 5 and text_lower.count(w) > 1:
                score += 2

        scored.append((score, chunk))

    scored.sort(key=lambda x: x[0], reverse=True)

    if scored[0][0] == 0:
        mid = len(chunks) // 2
        return chunks[max(0, mid - 1):mid + 2][:top_k]

    return [c for _, c in scored[:top_k]]