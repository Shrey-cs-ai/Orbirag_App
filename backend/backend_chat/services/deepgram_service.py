"""
Deepgram service — transcribe audio bytes → text.
Loads .env itself so it works regardless of import order.
"""

import os
from pathlib import Path


# ============================================================
# Load .env
# ============================================================
def _load_env():
    env_path = Path(__file__).resolve().parent.parent / ".env"
    if not env_path.exists():
        print(f"[Deepgram] .env not found at {env_path}")
        return
    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ[k.strip()] = v.strip()


_load_env()


_api_key = os.getenv("DEEPGRAM_API_KEY")
print(f"[Deepgram] API key: {'SET' if _api_key else 'MISSING'}")


# ============================================================
# Transcribe
# ============================================================
async def transcribe_audio(audio_bytes: bytes, language: str = "en") -> dict:
    """
    Send audio bytes to Deepgram and return:
        {"transcript": str, "confidence": float,
         "duration_seconds": float, "words": int}
    Raises RuntimeError on failure.
    """
    if not _api_key:
        raise RuntimeError("DEEPGRAM_API_KEY not set in .env")

    try:
        from deepgram import AsyncDeepgramClient

        # v7: AsyncDeepgramClient accepts api_key as a keyword argument
        client = AsyncDeepgramClient(api_key=_api_key)

        # v7: transcription parameters are now keyword arguments
        response = await client.listen.v1.media.transcribe_file(
            request=audio_bytes,
            model="nova-2",
            language=language,
            smart_format=True,
            punctuate=True,
        )

        # Response shape is unchanged in v7
        alt = response.results.channels[0].alternatives[0]
        transcript = alt.transcript or ""
        confidence = float(alt.confidence or 0.0)
        words = len(transcript.split())

        duration = 0.0
        try:
            duration = float(response.metadata.duration or 0.0)
        except Exception:
            pass

        print(
            f"[Deepgram] Transcribed {len(transcript)} chars "
            f"(confidence={confidence:.2f})"
        )

        return {
            "transcript": transcript,
            "confidence": confidence,
            "duration_seconds": duration,
            "words": words,
        }

    except Exception as e:
        print(f"[Deepgram] Error: {type(e).__name__}: {e}")
        raise RuntimeError(f"Deepgram transcription failed: {e}")