# ============================================================
# STEP 1: Load .env FIRST — before any service imports
# ============================================================
import os
from pathlib import Path


def _load_env():
    """Load .env into os.environ BEFORE importing services."""
    env_path = Path(__file__).resolve().parent / ".env"
    print(f"[ENV] Loading from: {env_path}")

    if not env_path.exists():
        raise FileNotFoundError(f".env not found at {env_path}")

    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                os.environ[key.strip()] = value.strip()


_load_env()

# Confirm both keys are loaded
_gem = os.getenv("GEMINI_API_KEY")
_dg = os.getenv("DEEPGRAM_API_KEY")
print(f"[ENV] GEMINI   : {'OK' if _gem else 'MISSING'}")
print(f"[ENV] DEEPGRAM : {'OK' if _dg else 'MISSING'}")
# ============================================================


# ============================================================
# STEP 2: Now safe to import everything else
# ============================================================
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from models import ChatRequest, ChatResponse, TranscribeResponse
from services.ai_service import get_chat_response
from services.deepgram_service import transcribe_audio


# ============================================================
# STEP 3: FastAPI app setup
# ============================================================
app = FastAPI(title="Orbirag API")

# Allow the Flutter app to make requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================
# STEP 4: Routes
# ============================================================
@app.get("/")
def read_root():
    return {"message": "Orbirag Chatbot API is running"}


@app.post("/chat", response_model=ChatResponse)
async def chat_endpoint(request: ChatRequest):
    """Main chat endpoint for the Ori chatbot."""
    ai_response = await get_chat_response(request.message, request.history)
    return ChatResponse(response=ai_response)


@app.post("/api/voice/transcribe", response_model=TranscribeResponse)
async def transcribe_voice(
    audio: UploadFile = File(...),
    language: str = "en",
):
    """
    Accepts an audio file and returns the transcribed text.
    Called by the Flutter voice input screen.
    """
    # Validate file type
    allowed_types = {
        "audio/wav", "audio/x-wav", "audio/wave",
        "audio/mp4", "audio/m4a", "audio/x-m4a",
        "audio/mpeg", "audio/mp3",
        "audio/webm",
        "audio/ogg",
        "application/octet-stream",   # ← ADD THIS
    }
    if audio.content_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported audio type: {audio.content_type}",
        )

    # Read bytes
    audio_bytes = await audio.read()

    # Size check (10 MB max)
    if len(audio_bytes) > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=413,
            detail="Audio file too large (max 10 MB)",
        )

    if len(audio_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty audio file")

    try:
        result = await transcribe_audio(audio_bytes, language=language)
        return TranscribeResponse(**result)
    except RuntimeError as e:
        raise HTTPException(status_code=500, detail=str(e))