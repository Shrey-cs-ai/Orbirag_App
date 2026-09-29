"""
Deepgram Nova-2 — speech-to-text.
"""

import os
from deepgram import (
    DeepgramClient,
    PrerecordedOptions,
    FileSource,
)

_api_key = os.getenv("DEEPGRAM_API_KEY")
if not _api_key:
    raise ValueError("DEEPGRAM_API_KEY not set in environment")

_client = DeepgramClient(_api_key)


async def transcribe_audio(audio_bytes: bytes, language: str = "en") -> dict:
    """Transcribe raw audio bytes. Returns a dict matching TranscribeResponse."""
    try:
        payload: FileSource = {"buffer": audio_bytes}
        options = PrerecordedOptions(
            model="nova-2",
            language=language,
            smart_format=True,
            punctuate=True,
            diarize=False,
        )

        response = await _client.listen.asyncrest.v("1").transcribe_file(
            payload, options
        )

        alt = response.results.channels[0].alternatives[0]
        return {
            "transcript": alt.transcript or "",
            "confidence": float(alt.confidence or 0.0),
            "duration_seconds": float(response.metadata.duration or 0.0),
            "words": len(alt.words or []),
        }
    except Exception as e:
        raise RuntimeError(f"Deepgram error: {type(e).__name__}: {e}")