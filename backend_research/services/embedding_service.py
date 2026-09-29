"""
Local embeddings via sentence-transformers.
Model: all-MiniLM-L6-v2 → 384-dim vectors, runs on CPU, free.

IMPORTANT: sentence-transformers is imported LAZILY (inside _get_model)
so that importing this module is instant. The heavy ML stack only loads
when embed_texts() is first called.
"""

import os
from typing import List

MODEL_NAME = "all-MiniLM-L6-v2"
EMBED_DIM = 384

# Module-level cache — None until the model is actually loaded
_model = None


def _get_model():
    """Load model on first use only. Not at import time."""
    global _model
    if _model is None:
        # Silence the tokenizers warning
        os.environ["TOKENIZERS_PARALLELISM"] = "false"

        print(f"[Embeddings] Loading {MODEL_NAME} (first call only)...")
        # ⬇️ This is the ONLY place sentence_transformers is imported
        from sentence_transformers import SentenceTransformer
        _model = SentenceTransformer(MODEL_NAME)
        print("[Embeddings] Model ready")

    return _model


def embed_texts(texts: List[str]) -> List[List[float]]:
    """Batch embed. Returns list of 384-dim float lists."""
    model = _get_model()
    vectors = model.encode(texts, normalize_embeddings=True)
    return [v.tolist() for v in vectors]


def embed_one(text: str) -> List[float]:
    return embed_texts([text])[0]