"""
RAG orchestration for Paper Orbit:
- parse PDF into pages
- chunk with overlap
- store in DuckDB VSS
- retrieve + ask Gemini
"""

import io
from typing import List, Dict

from pypdf import PdfReader

import vector_store
from services.ai_service import chat_with_context


CHUNK_SIZE = 900        # chars
CHUNK_OVERLAP = 150     # chars


def _chunk_text(text: str) -> List[str]:
    """Simple sliding-window chunker. Good enough for research papers."""
    text = text.strip()
    if not text:
        return []

    chunks = []
    start = 0
    while start < len(text):
        end = start + CHUNK_SIZE
        chunks.append(text[start:end])
        if end >= len(text):
            break
        start = end - CHUNK_OVERLAP
    return chunks


def index_pdf(pdf_bytes: bytes, filename: str, user_id: str) -> Dict:
    """
    Parse a PDF, chunk it, embed it, store it.
    Returns { doc_id, num_pages, num_chunks }.
    """
    reader = PdfReader(io.BytesIO(pdf_bytes))
    num_pages = len(reader.pages)

    chunk_rows = []
    idx = 0
    for page_num, page in enumerate(reader.pages, start=1):
        page_text = page.extract_text() or ""
        for piece in _chunk_text(page_text):
            chunk_rows.append({
                "text": piece,
                "page_number": page_num,
                "chunk_index": idx,
            })
            idx += 1

    if not chunk_rows:
        raise ValueError("No extractable text found in PDF")

    doc_id = vector_store.add_document(
        user_id=user_id,
        filename=filename,
        num_pages=num_pages,
        chunks=chunk_rows,
    )

    return {
        "doc_id": doc_id,
        "num_pages": num_pages,
        "num_chunks": len(chunk_rows),
    }


async def ask_document(doc_id: str, question: str, top_k: int = 5) -> Dict:
    """
    Retrieve relevant chunks + ask Gemini.
    Returns { response, sources: [{page, chunk_index, snippet}] }.
    """
    hits = vector_store.search(doc_id, question, top_k=top_k)
    if not hits:
        return {
            "response": "I couldn't find anything relevant in this document.",
            "sources": [],
        }

    context = "\n\n---\n\n".join(
        f"[Page {h['page_number']}]\n{h['text']}" for h in hits
    )

    answer = await chat_with_context(question, context)

    sources = [
        {
            "page": h["page_number"],
            "chunk_index": h["chunk_index"],
            "snippet": h["text"][:180] + ("..." if len(h["text"]) > 180 else ""),
        }
        for h in hits
    ]

    return {"response": answer, "sources": sources}