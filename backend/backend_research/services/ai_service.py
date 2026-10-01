"""
Gemini wrapper — loads .env itself, uses a fallback chain for reliability.
"""

import asyncio
import os
import json
from pathlib import Path
from typing import Optional
from google import genai


# ============================================================
# Load .env
# ============================================================
def _load_env():
    env_path = Path(__file__).resolve().parent.parent / ".env"
    print(f"[ai_service] Loading .env from: {env_path}")
    if not env_path.exists():
        print(f"[ai_service] ⚠️  .env NOT FOUND at {env_path}")
        return
    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ[k.strip()] = v.strip()
    print("[ai_service] .env loaded")


_load_env()


# ============================================================
# Gemini client
# ============================================================
_api_key = os.getenv("GEMINI_API_KEY")
print(f"[ai_service] GEMINI_API_KEY = "
      f"{'SET (' + _api_key[:10] + '...)' if _api_key else 'MISSING'}")

if not _api_key or _api_key in (
    "your_real_gemini_key_here",
    "AIzaSyPLACEHOLDER",
    "PLACEHOLDER",
):
    raise ValueError(
        "GEMINI_API_KEY not set in .env — open backend/.env and paste a real key"
    )

_client = genai.Client(api_key=_api_key)


# ============================================================
# Model fallback chain — try each in order
# ============================================================
MODELS = [
    "gemini-3.8-flash",
    "gemini-3.7-flash",
    "gemini-3.6-flash",
    "gemini-3.5-flash",
    "gemini-2.5-flash-lite",
    "gemini-flash-lite-latest",
]

SYSTEM_INSTRUCTION = """You are Ori, a friendly AI research assistant for students.
Be concise, warm, and cite sources when relevant. Never invent citations."""


# ============================================================
# Internal: generate with fallback
# ============================================================
async def _generate_with_fallback(prompt: str, json_mode: bool = False) -> str:
    """Try each model in MODELS until one succeeds."""
    last_error = None

    for model_name in MODELS:
        for attempt in range(2):
            try:
                if json_mode:
                    response = _client.models.generate_content(
                        model=model_name,
                        contents=prompt,
                        config={"response_mime_type": "application/json"},
                    )
                else:
                    response = _client.models.generate_content(
                        model=model_name,
                        contents=prompt,
                    )

                print(f"[AI] Success with {model_name}")
                return response.text or ""

            except Exception as e:
                last_error = e
                msg = str(e).lower()

                # Retry same model on 503/429
                if ("503" in msg or "unavailable" in msg or "429" in msg) and attempt < 1:
                    wait = 2 * (attempt + 1)
                    print(f"[AI] {model_name} busy, retry in {wait}s...")
                    await asyncio.sleep(wait)
                    continue

                # Other error → try next model
                print(f"[AI] {model_name} failed: {type(e).__name__}")
                break

        print(f"[AI] Switching to next model...")

    # All models failed
    raise last_error


# ============================================================
# Feature 1: Ori chatbot (plain text)
# ============================================================
async def get_chat_response(message: str, history: list) -> str:
    try:
        parts = [SYSTEM_INSTRUCTION, ""]
        recent = history[-5:] if len(history) > 5 else (history or [])
        for msg in recent:
            role = "User" if msg.get("role") == "user" else "Ori"
            parts.append(f"{role}: {msg.get('content', '')}")
        parts.append(f"User: {message}")
        parts.append("Ori:")
        prompt = "\n".join(parts)
        return await _generate_with_fallback(prompt)
    except Exception as e:
        print(f"[Gemini] chat error: {type(e).__name__}: {e}")
        return "I'm having trouble responding right now. Please try again."


# ============================================================
# Feature 2: JSON generation (for structured prompts)
# ============================================================
async def generate_json(prompt: str) -> Optional[dict]:
    """Ask Gemini for strict JSON and parse it. Returns None on failure."""
    try:
        text = await _generate_with_fallback(prompt, json_mode=True)
        text = (text or "").strip()
        # Strip code fences if the model adds them anyway
        if text.startswith("```"):
            text = text.strip("`")
            if text.startswith("json"):
                text = text[4:]
        return json.loads(text)
    except Exception as e:
        print(f"[Gemini] json error: {type(e).__name__}: {e}")
        return None


# ============================================================
# Feature 3: Chat with RAG context (Paper Orbit)
# ============================================================
async def chat_with_context(question: str, context: str) -> str:
    prompt = f"""You are Ori. Answer the user's question USING ONLY the context below.
If the answer isn't in the context, say so honestly.

CONTEXT:
{context}

USER QUESTION: {question}

Answer:"""
    try:
        return await _generate_with_fallback(prompt)
    except Exception as e:
        print(f"[Gemini] rag error: {type(e).__name__}: {e}")
        return "I'm having trouble reading the document right now."


# ============================================================
# Feature 4: Literature search — build Boolean query
# ============================================================
BUILD_QUERY_PROMPT = """You are a research librarian. Given a topic,
extract search keywords and a Boolean query for academic databases.

TOPIC: {topic}

Return ONLY valid JSON:
{{
  "keywords": ["term1", "term2", "term3", "term4", "term5"],
  "synonyms": ["related1", "related2", "related3"],
  "boolean_query": "term1 AND (term2 OR term3) AND term4"
}}

Rules:
- keywords: 3-6 core concepts, all lowercase
- synonyms: 3-5 related/alternative terms
- boolean_query: valid syntax for Semantic Scholar / Scopus
"""


async def build_search_query(topic: str) -> Optional[dict]:
    """Ask Gemini to extract keywords + Boolean query."""
    return await generate_json(BUILD_QUERY_PROMPT.format(topic=topic))


# ============================================================
# Feature 5: Literature search — summarize a paper
# ============================================================
SUMMARIZE_PROMPT = """Summarize this academic paper in ONE sentence (max 25 words).
Focus on what it found or contributed — not on what it promises to do.

TITLE: {title}
ABSTRACT: {abstract}

One-sentence summary:"""


async def summarize_paper(title: str, abstract: str) -> str:
    """Single-sentence AI summary of a paper."""
    if not abstract or len(abstract.strip()) < 30:
        return "No abstract available."
    try:
        prompt = SUMMARIZE_PROMPT.format(title=title, abstract=abstract[:1500])
        result = await _generate_with_fallback(prompt)
        return result.strip().strip('"')
    except Exception as e:
        print(f"[Gemini] summarize error: {type(e).__name__}: {e}")
        return abstract[:150] + "..."