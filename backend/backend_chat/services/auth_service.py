import os
from pathlib import Path
from fastapi import HTTPException, Header

try:
    import firebase_admin
    from firebase_admin import credentials, auth
except ImportError:
    firebase_admin = None
    credentials = None
    auth = None

_firebase_auth = None
_init_attempted = False


def _get_auth():
    global _firebase_auth, _init_attempted
    if _firebase_auth is not None:
        return _firebase_auth
    if _init_attempted:
        return _firebase_auth
    _init_attempted = True

    if firebase_admin is None or credentials is None or auth is None:
        return None

    try:
        base_dir = Path(__file__).resolve().parent.parent
        candidates = [
            os.getenv("FIREBASE_SERVICE_ACCOUNT"),
            os.getenv("FIREBASE_CREDENTIALS_PATH"),
            os.getenv("GOOGLE_APPLICATION_CREDENTIALS"),
            str(base_dir / "firebase-service-account.json"),
            str(base_dir.parent / "backend_research" / "firebase-service-account.json"),
            str(base_dir.parent / "firebase-service-account.json"),
            str(Path.cwd() / "firebase-service-account.json"),
        ]

        cred_path = None
        for candidate in candidates:
            if candidate:
                p = Path(candidate)
                if p.exists() and p.stat().st_size > 0:
                    cred_path = p
                    break

        if cred_path and not firebase_admin._apps:
            cred = credentials.Certificate(str(cred_path))
            firebase_admin.initialize_app(cred)

        if firebase_admin._apps:
            _firebase_auth = auth
        return _firebase_auth
    except Exception as e:
        print(f"[ChatAuth] Firebase Admin init failed: {e}")
        return None


async def verify_token(authorization: str = Header(...)) -> str:
    """Verify the Firebase ID token and return the user's UID."""
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization header")
    
    id_token = authorization.split("Bearer ")[1]
    fb_auth = _get_auth()
    if not fb_auth:
        raise HTTPException(status_code=503, detail="Firebase Auth service is not configured")

    try:
        decoded_token = fb_auth.verify_id_token(id_token)
        return decoded_token["uid"]
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired token")