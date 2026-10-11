import os
from pathlib import Path
from typing import List, Dict, Optional

_initialized = False
_firebase_auth = None


def _ensure_initialized():
    global _initialized, _firebase_auth
    if _initialized and _firebase_auth is not None:
        return
    try:
        import firebase_admin
        from firebase_admin import credentials, auth as fb_auth

        cred_path = Path(__file__).resolve().parent.parent / "firebase-service-account.json"
        if not cred_path.exists() or cred_path.stat().st_size == 0:
            print(f"[FirebaseAdmin] No service account at {cred_path}")
            _initialized = True
            _firebase_auth = None
            return

        if not firebase_admin._apps:
            cred = credentials.Certificate(str(cred_path))
            firebase_admin.initialize_app(cred)

        _firebase_auth = fb_auth
        _initialized = True
        print("[FirebaseAdmin] Ready")
    except Exception as e:
        print(f"[FirebaseAdmin] Init failed: {e}")
        _initialized = True
        _firebase_auth = None


def list_firebase_users(max_results: int = 500) -> List[Dict]:
    """
    Return a list of Firebase users as dicts with these fields:
    {
      "uid": str,
      "email": str | None,
      "display_name": str | None,
      "provider": str,          # e.g. "password", "google.com", "github.com"
      "disabled": bool,
      "created_at": str | None, # ISO 8601
      "last_sign_in": str | None,
      "photo_url": str | None,
    }
    """
    _ensure_initialized()
    if _firebase_auth is None:
        return []

    try:
        users: List[Dict] = []
        page = _firebase_auth.list_users()
        count = 0
        for u in page.iterate_all():
            providers = []
            try:
                if u.provider_data:
                    providers = [p.provider_id for p in u.provider_data]
            except Exception:
                pass

            users.append({
                "uid": u.uid,
                "email": u.email,
                "display_name": u.display_name,
                "provider": providers[0] if providers else "unknown",
                "disabled": bool(u.disabled),
                "created_at": (
                    u.user_metadata.creation_timestamp
                    if u.user_metadata else None
                ),
                "last_sign_in": (
                    u.user_metadata.last_sign_in_timestamp
                    if u.user_metadata else None
                ),
                "photo_url": u.photo_url,
            })
            count += 1
            if count >= max_results:
                break

        return users
    except Exception as e:
            print(f"[FirebaseAdmin] list_users failed: {e}")
            return []


# Initialize once on module load
_ensure_initialized()
