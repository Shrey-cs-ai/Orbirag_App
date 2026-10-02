# ============================================================
# AI Service — Gemini wrapper for Orbirag
# ============================================================
import asyncio
import os
import httpx
from pathlib import Path
from typing import List

from google import genai


# ============================================================
# 1. LOAD .ENV
# ============================================================
def _load_env_file():
    env_path = Path(__file__).resolve().parent.parent / ".env"
    if not env_path.exists():
        raise FileNotFoundError(f".env file not found at: {env_path}")
    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, value = line.split("=", 1)
                os.environ[key.strip()] = value.strip()


_load_env_file()


# ============================================================
# 2. GEMINI CLIENT
# ============================================================
api_key = os.getenv("GEMINI_API_KEY")
if not api_key:
    raise ValueError("GEMINI_API_KEY not found in .env")

client = genai.Client(api_key=api_key)


# ============================================================
# 3. MODEL FALLBACK CHAIN
# Try these in order when a model returns 503
# ============================================================
MODELS = [
    "gemini-3.8-flash",             # primary — newest flash
    "gemini-3.7-flash",             # fallback 1
    "gemini-3.5-flash",             # fallback 2
    "gemini-2.5-flash-lite",        # fallback 3 — lightest
    "gemini-flash-lite-latest",     # fallback 4 — ultimate fallback
]


# ============================================================
# 4. SYSTEM PROMPTS
# ============================================================
ORI_SYSTEM = """You are Ori, an AI research assistant for students.
Be friendly, concise, and helpful. Keep answers under 150 words."""

PAPER_SYSTEM = """You are analyzing a research paper. Answer based ONLY on
the provided context. Cite page numbers when possible. Keep answers
under 150 words."""


# ============================================================
# 5. RETRY + FALLBACK HELPER
# ============================================================
async def _generate_with_fallback(prompt: str) -> str:
    """
    Try each model in MODELS.
    Within each model, retry twice on 503/UNAVAILABLE.
    """
    last_error = None

    for model_name in MODELS:
        for attempt in range(2):   # 2 attempts per model
            try:
                response = client.models.generate_content(
                    model=model_name,
                    contents=prompt,
                )
                print(f"[AI] Success with {model_name}")
                return response.text

            except Exception as e:
                last_error = e
                msg = str(e).lower()

                # 503 / 429 → retry with the same model
                if "503" in msg or "unavailable" in msg or "429" in msg:
                    if attempt < 1:
                        wait = 2 * (attempt + 1)
                        print(f"[AI] {model_name} busy, retry in {wait}s...")
                        await asyncio.sleep(wait)
                        continue

                # Other errors → move to next model
                print(f"[AI] {model_name} failed: {type(e).__name__}")
                break

        # Try next model
        print(f"[AI] Switching to next model...")

    # All models failed
    raise last_error


# ============================================================
# 6. FEATURE — Ori Chatbot
# ============================================================
async def get_chat_response(message: str, history: list) -> str:
    try:
        parts = [ORI_SYSTEM, ""]
        recent = history[-5:] if len(history) > 5 else history
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

        recent = history[-3:] if len(history) > 3 else history
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

#word counter
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
    # (Implement OpenAI logic here if needed)
    return []