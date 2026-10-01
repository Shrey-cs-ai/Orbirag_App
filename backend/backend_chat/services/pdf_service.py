import io
import re
import uuid
from typing import Dict, List

from pypdf import PdfReader


# ============================================================
# In-memory storage
# ============================================================
_papers: Dict[str, dict] = {}


# ============================================================
# Extract text from PDF
# ============================================================
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


# ============================================================
# Chunk long text into smaller pieces
# ============================================================
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


# ============================================================
# Store and retrieve papers (in-memory)
# ============================================================
def save_paper(filename: str, chunks: List[dict]) -> str:
    """Store a paper and return its ID."""
    paper_id = str(uuid.uuid4())
    _papers[paper_id] = {
        "filename": filename,
        "chunks": chunks,
    }
    print(f"[PDF] Saved paper {paper_id} ({filename}) with {len(chunks)} chunks")
    return paper_id


def get_paper(paper_id: str) -> dict | None:
    return _papers.get(paper_id)


def get_all_papers() -> Dict[str, dict]:
    return _papers


# ============================================================
# Find relevant chunks for a question
# ============================================================
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