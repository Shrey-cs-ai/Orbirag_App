import os
from pathlib import Path

from google import genai


# ==================== MANUAL .ENV LOADER ====================
# Reads .env directly — avoids python-dotenv + uvicorn reload issues
def _load_env_file():
    env_path = Path(__file__).resolve().parent.parent / ".env"
    if not env_path.exists():
        raise FileNotFoundError(f".env file not found at: {env_path}")

    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            # Skip blanks and comments
            if not line or line.startswith("#"):
                continue
            # Parse KEY=VALUE
            if "=" in line:
                key, value = line.split("=", 1)
                os.environ[key.strip()] = value.strip()


_load_env_file()
# ============================================================


api_key = os.getenv("GEMINI_API_KEY")
if not api_key:
    raise ValueError("GEMINI_API_KEY not found in .env")

client = genai.Client(api_key=api_key)

SYSTEM_INSTRUCTION = """You are Ori, an AI research assistant for students.
Be friendly, concise, and helpful."""


async def get_chat_response(message: str, history: list) -> str:
    try:
        prompt_parts = [SYSTEM_INSTRUCTION, ""]
        for msg in history:
            role = "User" if msg.get("role") == "user" else "Ori"
            prompt_parts.append(f"{role}: {msg.get('content', '')}")
        prompt_parts.append(f"User: {message}")
        prompt_parts.append("Ori:")
        prompt = "\n".join(prompt_parts)

        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
        )
        return response.text
    except Exception as e:
        print(f"Gemini error: {type(e).__name__}: {e}")
        return "I'm having trouble responding right now. Please try again."