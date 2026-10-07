# ============================================================
# AI Service — LLM wrapper for Orbirag Chat Backend
# Groq first (fast, generous free tier), Gemini fallback
# ============================================================
import asyncio
import os
import json
import httpx
from pathlib import Path
from typing import List, Optional

from google import genai

try:
    from groq import AsyncGroq
    _GROQ_AVAILABLE = True
except ImportError:
    AsyncGroq = None
    _GROQ_AVAILABLE = False


# ============================================================
# 1. LOAD .ENV
# ============================================================
def _load_env_file():
    env_path = Path(__file__).resolve().parent.parent / ".env"
    print(f"[ai_service] Loading .env from: {env_path}")
    if not env_path.exists():
        print("[ai_service] .env NOT FOUND")
        return
    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, value = line.split("=", 1)
                os.environ[key.strip()] = value.strip()
    print("[ai_service] .env loaded")


_load_env_file()


# ============================================================
# 2. CLIENTS (Groq + Gemini)
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


# ============================================================
# 3. MODELS
# ============================================================
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
    "gemini-2.5-flash-lite",
    "gemini-flash-lite-latest",
]


# ============================================================
# 4. SYSTEM PROMPTS
# ============================================================
ORI_SYSTEM = """You are Ori, a friendly AI research assistant for students.
Be concise, warm, and cite sources when relevant. Never invent citations. Keep answers under 150 words."""

PAPER_SYSTEM = """You are analyzing a research paper. Answer based ONLY on
the provided context. Cite page numbers when possible. Keep answers
under 150 words."""


# ============================================================
# 5. RETRY + FALLBACK HELPERS
# ============================================================
async def _try_groq(prompt: str, json_mode: bool = False) -> Optional[str]:
    if not _groq_client:
        return None

    for model_name in GROQ_MODELS:
        for attempt in range(2):
            try:
                kwargs = {
                    "model": model_name,
                    "messages": [{"role": "user", "content": prompt}],
                    "temperature": 0.2 if json_mode else 0.7,
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


async def _try_gemini(prompt: str, json_mode: bool = False) -> Optional[str]:
    if not _gemini_client:
        return None

    for model_name in GEMINI_MODELS:
        for attempt in range(2):
            try:
                cfg = {"automatic_function_calling": {"disable": True}}
                if json_mode:
                    cfg["response_mime_type"] = "application/json"

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


async def _generate_with_fallback(prompt: str, json_mode: bool = False) -> str:
    # 1. Try Groq (fast, high quota)
    result = await _try_groq(prompt, json_mode=json_mode)
    if result is not None:
        return result

    # 2. Try Gemini
    print("[AI] Groq exhausted, switching to Gemini...")
    result = await _try_gemini(prompt, json_mode=json_mode)
    if result is not None:
        return result

    raise RuntimeError("All LLM providers failed (Groq + Gemini)")


# ============================================================
# 6. FEATURE — Ori Chatbot
# ============================================================
async def get_chat_response(message: str, history: list) -> str:
    try:
        parts = [ORI_SYSTEM, ""]
        recent = history[-5:] if len(history) > 5 else (history or [])
        for msg in recent:
            role = "User" if msg.get("role") == "user" else "Ori"
            parts.append(f"{role}: {msg.get('content', '')}")
        parts.append(f"User: {message}")
        parts.append("Ori:")
        prompt = "\n".join(parts)

        return await _generate_with_fallback(prompt)
    except Exception as e:
        print(f"[AI] chat error: {type(e).__name__}: {e}")
        return "I'm having trouble responding right now. Please try again."


# ============================================================
# 7. FEATURE — Paper Orbit
# ============================================================
async def get_paper_response(
    question: str,
    context: str,
    history: list,
) -> str:
    try:
        max_context = 3000
        if len(context) > max_context:
            context = context[:max_context] + "\n...[truncated]"

        parts = [PAPER_SYSTEM, ""]
        parts.append("Context from the paper:")
        parts.append("---")
        parts.append(context)
        parts.append("---")
        parts.append("")

        recent = history[-3:] if len(history) > 3 else (history or [])
        for msg in recent:
            role = "User" if msg.get("role") == "user" else "Ori"
            parts.append(f"{role}: {msg.get('content', '')}")

        parts.append(f"User: {question}")
        parts.append("Ori:")
        prompt = "\n".join(parts)

        print(f"[AI] paper prompt length: {len(prompt)} chars")
        return await _generate_with_fallback(prompt)
    except Exception as e:
        print(f"[AI] paper error: {type(e).__name__}: {e}")
        return "I'm having trouble responding right now. Please try again."


# ============================================================
# 8. FEATURE — Word Counter / Suggestions
# ============================================================
LANGUAGETOOL_URL = os.getenv("LANGUAGETOOL_URL", "https://api.languagetool.org/v2/check")
AI_PROVIDER = os.getenv("AI_PROVIDER", "languagetool")

async def get_suggestions(text: str, ignore_words: List[str] = []) -> List[dict]:
    if not text.strip():
        return []

    if AI_PROVIDER == "openai":
        raw = await _get_from_openai(text)
    else:
        raw = await _get_from_languagetool(text)

    # Filter ignored words (case-insensitive)
    ignore_set = {w.lower() for w in ignore_words}
    return [s for s in raw if s["original"].lower() not in ignore_set]

async def _get_from_languagetool(text: str) -> List[dict]:
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            response = await client.post(
                LANGUAGETOOL_URL,
                data={"text": text, "language": "en-US"}
            )
            response.raise_for_status()
            data = response.json()
            matches = data.get("matches", [])

            suggestions = []
            for i, match in enumerate(matches):
                replacements = match.get("replacements", [])
                if not replacements:
                    continue
                
                replacement = replacements[0].get("value", "")
                offset = match.get("offset", 0)
                length = match.get("length", 0)
                original = text[offset:offset + length]

                suggestions.append({
                    "id": f"lt-{i}-{offset}",
                    "type": _map_type(match.get("rule", {}).get("issueType")),
                    "original": original,
                    "replacement": replacement,
                    "message": match.get("message", ""),
                    "start": offset,
                    "end": offset + length,
                })
            return suggestions
    except Exception as e:
        print(f"[AI Service] LanguageTool error: {e}")
        return []

def _map_type(issue_type: str) -> str:
    mapping = {
        "misspelling": "spelling",
        "grammar": "grammar",
        "style": "style",
    }
    return mapping.get(issue_type, "suggestion")

async def _get_from_openai(text: str) -> List[dict]:
    """Optional: Use OpenAI instead of LanguageTool."""
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        return []
    return []