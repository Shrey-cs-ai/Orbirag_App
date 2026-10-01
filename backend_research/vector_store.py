"""
DuckDB + VSS vector store for Paper Orbit.
File-based, zero-infra, SQL-queryable.
"""

import os
import uuid
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any

import duckdb

from services.embedding_service import embed_texts, EMBED_DIM

DB_PATH = os.getenv("DUCKDB_PATH", "./vectors/orbirag_vectors.duckdb")


def _ensure_dir():
    Path(DB_PATH).parent.mkdir(parents=True, exist_ok=True)


def _connect() -> duckdb.DuckDBPyConnection:
    _ensure_dir()
    con = duckdb.connect(DB_PATH)
    con.execute("INSTALL vss; LOAD vss;")
    # HNSW index needs this pragma
    con.execute("SET hnsw_enable_experimental_persistence = true;")
    return con


def init_schema():
    """Create tables + vector index. Safe to call repeatedly."""
    con = _connect()
    try:
        con.execute(f"""
            CREATE TABLE IF NOT EXISTS documents (
                doc_id      VARCHAR PRIMARY KEY,
                user_id     VARCHAR,
                filename    VARCHAR,
                num_pages   INTEGER,
                num_chunks  INTEGER,
                uploaded_at TIMESTAMP
            );
        """)

        con.execute(f"""
            CREATE TABLE IF NOT EXISTS chunks (
                chunk_id     VARCHAR PRIMARY KEY,
                doc_id       VARCHAR,
                chunk_index  INTEGER,
                page_number  INTEGER,
                text         TEXT,
                embedding    FLOAT[{EMBED_DIM}]
            );
        """)

        # HNSW index on embedding for fast cosine search
        try:
            con.execute("""
                CREATE INDEX IF NOT EXISTS chunks_embedding_idx
                ON chunks
                USING HNSW (embedding)
                WITH (metric = 'cosine');
            """)
        except Exception as e:
            print(f"[Vector] HNSW index skipped: {e}")

        print("[Vector] schema ready")
    finally:
        con.close()


def add_document(
    user_id: str,
    filename: str,
    num_pages: int,
    chunks: List[Dict[str, Any]],
) -> str:
    """
    chunks: list of { text, page_number, chunk_index }
    Returns doc_id.
    """
    doc_id = str(uuid.uuid4())
    con = _connect()
    try:
        con.execute(
            "INSERT INTO documents VALUES (?, ?, ?, ?, ?, ?)",
            [doc_id, user_id, filename, num_pages, len(chunks), datetime.utcnow()],
        )

        texts = [c["text"] for c in chunks]
        vectors = embed_texts(texts)

        rows = [
            (
                str(uuid.uuid4()),
                doc_id,
                c["chunk_index"],
                c["page_number"],
                c["text"],
                v,
            )
            for c, v in zip(chunks, vectors)
        ]
        con.executemany(
            "INSERT INTO chunks VALUES (?, ?, ?, ?, ?, ?)",
            rows,
        )
        print(f"[Vector] stored {len(rows)} chunks for {filename}")
        return doc_id
    finally:
        con.close()


def search(doc_id: str, query: str, top_k: int = 5) -> List[Dict[str, Any]]:
    """Cosine similarity search restricted to one document."""
    from services.embedding_service import embed_one
    q_vec = embed_one(query)

    con = _connect()
    try:
        result = con.execute(
            """
            SELECT chunk_index, page_number, text,
                   array_cosine_similarity(embedding, ?::FLOAT[384]) AS score
            FROM chunks
            WHERE doc_id = ?
            ORDER BY score DESC
            LIMIT ?;
            """,
            [q_vec, doc_id, top_k],
        ).fetchall()

        return [
            {
                "chunk_index": r[0],
                "page_number": r[1],
                "text": r[2],
                "score": float(r[3]),
            }
            for r in result
        ]
    finally:
        con.close()


def document_exists(doc_id: str) -> bool:
    con = _connect()
    try:
        row = con.execute(
            "SELECT 1 FROM documents WHERE doc_id = ?", [doc_id]
        ).fetchone()
        return row is not None
    finally:
        con.close()