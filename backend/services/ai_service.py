# ============================================================
# AI Service — Gemini wrapper for Orbirag
# ============================================================
import asyncio
import os
from pathlib import Path

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