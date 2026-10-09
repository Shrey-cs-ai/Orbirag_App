"""
LLM wrapper — tries Groq first (14,400 free req/day),
then falls back to Gemini (better quality, lower free quota).
"""

import asyncio
import os
import json
from pathlib import Path
from typing import Optional

try:
    from google import genai  # type: ignore[import-untyped]
except ImportError as _exc:
    raise ImportError("Install google-genai: pip install google-genai") from _exc

try:
    from groq import AsyncGroq  # type: ignore[import-untyped]
    _GROQ_AVAILABLE = True
except ImportError:
    AsyncGroq = None
    _GROQ_AVAILABLE = False


# ============================================================
# Load .env
# ============================================================
def _load_env():
    env_path = Path(__file__).resolve().parent.parent / ".env"
    print(f"[ai_service] Loading .env from: {env_path}")
    if not env_path.exists():
        print("[ai_service] .env NOT FOUND")
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
# Providers
# ============================================================
_groq_key = os.getenv("GROQ_API_KEY")
_gemini_key = os.getenv("GEMINI_API_KEY")

print(f"[ai_service] GROQ_API_KEY   = {'SET' if _groq_key else 'MISSING'}")
print(f"[ai_service] GEMINI_API_KEY = {'SET' if _gemini_key else 'MISSING'}")

_groq_client = None
if _groq_key and _GROQ_AVAILABLE:
    _groq_client = AsyncGroq(api_key=_groq_key)
    print("[ai_service] Groq client ready")

_gemini_client = None
if _gemini_key:
    _gemini_client = genai.Client(api_key=_gemini_key)
    print("[ai_service] Gemini client ready")

if not _groq_client and not _gemini_client:
    raise ValueError(
        "No LLM configured — set GROQ_API_KEY or GEMINI_API_KEY in .env"
    )


GROQ_MODELS = [
    "openai/gpt-oss-120b",
    "openai/gpt-oss-20b",
    "qwen/qwen3.8-27b",
    "allam-2-7b",
]

GEMINI_MODELS = [
    "gemini-3.8-flash",
    "gemini-3.7-flash",
    "gemini-3.6-flash",
    "gemini-3.5-flash",
]

SYSTEM_INSTRUCTION = """You are Ori, a friendly AI research assistant for students.
Be concise, warm, and cite sources when relevant. Never invent citations."""


# ============================================================
# Groq
# ============================================================
async def _try_groq(prompt: str, json_mode: bool, temperature: Optional[float] = None) -> Optional[str]:
    if not _groq_client:
        return None

    for model_name in GROQ_MODELS:
        for attempt in range(2):
            try:
                t = temperature if temperature is not None else (0.2 if json_mode else 0.7)
                kwargs = {
                    "model": model_name,
                    "messages": [{"role": "user", "content": prompt}],
                    "temperature": t,
                }
                if json_mode:
                    kwargs["response_format"] = {"type": "json_object"}

                response = await _groq_client.chat.completions.create(**kwargs)
                text = response.choices[0].message.content or ""
                print(f"[AI] Groq success: {model_name}")
                return text

            except Exception as e:
                msg = str(e).lower()
                if ("429" in msg or "rate" in msg or "503" in msg) and attempt < 1:
                    print(f"[AI] Groq {model_name} busy, retry in 1s...")
                    await asyncio.sleep(1)
                    continue

                print(f"[AI] Groq {model_name} failed: {type(e).__name__}")
                break

    return None


# ============================================================
# Gemini
# ============================================================
async def _try_gemini(prompt: str, json_mode: bool, temperature: Optional[float] = None) -> Optional[str]:
    if not _gemini_client:
        return None

    for model_name in GEMINI_MODELS:
        for attempt in range(2):
            try:
                cfg = {"automatic_function_calling": {"disable": True}}
                if json_mode:
                    cfg["response_mime_type"] = "application/json"
                if temperature is not None:
                    cfg["temperature"] = temperature

                response = _gemini_client.models.generate_content(
                    model=model_name,
                    contents=prompt,
                    config=cfg,
                )
                print(f"[AI] Gemini success: {model_name}")
                return response.text or ""

            except Exception as e:
                msg = str(e).lower()
                if ("503" in msg or "unavailable" in msg or "429" in msg) and attempt < 1:
                    print(f"[AI] Gemini {model_name} busy, retry in 1s...")
                    await asyncio.sleep(1)
                    continue

                print(f"[AI] Gemini {model_name} failed: {type(e).__name__}")
                break

    return None


# ============================================================
# Combined fallback — Groq first, then Gemini
# ============================================================
async def _generate_with_fallback(
    prompt: str,
    json_mode: bool = False,
    temperature: Optional[float] = None,
) -> str:
    # 1. Try Groq (fast, huge free quota)
    result = await _try_groq(prompt, json_mode, temperature)
    if result is not None:
        return result

    # 2. Try Gemini (higher quality, lower quota)
    print("[AI] Groq exhausted, switching to Gemini...")
    result = await _try_gemini(prompt, json_mode, temperature)
    if result is not None:
        return result

    raise RuntimeError("All LLM providers failed (Groq + Gemini)")


# ============================================================
# Feature 1: Ori chatbot
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
        print(f"[LLM] chat error: {type(e).__name__}: {e}")
        return "I'm having trouble responding right now. Please try again."


# ============================================================
# Feature 2: JSON generation
# ============================================================
async def generate_json(prompt: str) -> Optional[dict]:
    try:
        text = await _generate_with_fallback(prompt, json_mode=True)
        text = (text or "").strip()
        if text.startswith("```"):
            text = text.strip("`")
            if text.startswith("json"):
                text = text[4:]
        return json.loads(text)
    except Exception as e:
        print(f"[LLM] json error: {type(e).__name__}: {e}")
        return None


# ============================================================
# Feature 3: RAG context (Paper Orbit)
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
        print(f"[LLM] rag error: {type(e).__name__}: {e}")
        return "I'm having trouble reading the document right now."


# ============================================================
# Feature 4: Build Boolean search query
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
    return await generate_json(BUILD_QUERY_PROMPT.format(topic=topic))


# ============================================================
# Feature 5: Summarize a paper
# ============================================================
SUMMARIZE_PROMPT = """Summarize this academic paper in ONE sentence (max 25 words).
Focus on what it found or contributed — not on what it promises to do.

TITLE: {title}
ABSTRACT: {abstract}

One-sentence summary:"""


async def summarize_paper(title: str, abstract: str) -> str:
    if not abstract or len(abstract.strip()) < 30:
        return "No abstract available."
    try:
        prompt = SUMMARIZE_PROMPT.format(title=title, abstract=abstract[:1500])
        result = await _generate_with_fallback(prompt)
        return result.strip().strip('"')
    except Exception as e:
        print(f"[LLM] summarize error: {type(e).__name__}: {e}")
        return abstract[:150] + "..."