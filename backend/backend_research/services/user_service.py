from typing import List, Optional
from uuid import UUID
from sqlalchemy.orm import Session

from models import User
from schemas import UserCreate
from services.auth_service import hash_password


def get_by_username(db: Session, username: str) -> Optional[User]:
    return db.query(User).filter(User.username == username).first()


def get_by_id(db: Session, user_id) -> Optional[User]:
    try:
        uid = UUID(str(user_id))
    except (ValueError, AttributeError):
        return None
    return db.query(User).filter(User.id == uid).first()


def list_users(db: Session, search: Optional[str] = None) -> List[User]:
    q = db.query(User)
    if search:
        pattern = f"%{search.lower()}%"
        q = q.filter(
            (User.username.ilike(pattern)) | (User.email.ilike(pattern))
        )
    return q.order_by(User.created_at.desc()).all()


def create_user(db: Session, data: UserCreate) -> User:
    user = User(
        username=data.username.strip(),
        email=(data.email or "").strip() or None,
        password_hash=hash_password(data.password),
        role=data.role,
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def set_active(db: Session, user_id: UUID, active: bool) -> Optional[User]:
    user = get_by_id(db, user_id)
    if not user:
        return None
    user.is_active = active
    db.commit()
    db.refresh(user)
    return user


def set_role(db: Session, user_id: UUID, role: str) -> Optional[User]:
    user = get_by_id(db, user_id)
    if not user:
        return None
    user.role = role
    db.commit()
    db.refresh(user)
    return user


def reset_password(db: Session, user_id: UUID, new_password: str) -> Optional[User]:
    user = get_by_id(db, user_id)
    if not user:
        return None
    user.password_hash = hash_password(new_password)
    db.commit()
    db.refresh(user)
    return user


def delete_user(db: Session, user_id: UUID) -> bool:
    user = get_by_id(db, user_id)
    if not user:
        return False
    db.delete(user)
    db.commit()
    return True


def set_avatar(db: Session, user_id, avatar_base64: Optional[str]) -> Optional[User]:
    user = get_by_id(db, user_id)
    if not user:
        return None
    user.avatar_base64 = avatar_base64
    db.commit()
    db.refresh(user)
    return user


def upsert_user_from_firebase(
    db: Session,
    firebase_uid: str,
    email: Optional[str] = None,
    display_name: Optional[str] = None,
    provider: str = "unknown",
    photo_url: Optional[str] = None,
) -> User:
    """
    Create or update a User row keyed on firebase_uid.
    The `username` field falls back to email if display_name is missing.
    """
    user = db.query(User).filter(User.username == firebase_uid).first()

    if not user and email:
        user = db.query(User).filter(User.email == email).first()

    username = display_name or email or firebase_uid

    if user is None:
        user = User(
            username=firebase_uid,
            email=email,
            password_hash="firebase-managed",
            role="user",
            is_active=True,
            avatar_base64=photo_url,
        )
        db.add(user)
    else:
        if email:
            user.email = email
        if photo_url:
            user.avatar_base64 = photo_url

    db.commit()
    db.refresh(user)
    return user


def list_all_users_unified(db: Session, search: Optional[str] = None):
    """
    Merge Firebase Auth users with local Postgres metadata.
    Returns a list of dicts suitable for the admin dashboard.
    """
    from services.firebase_admin_service import list_firebase_users

    firebase_users = list_firebase_users()
    db_users = {u.username: u for u in db.query(User).all()}

    merged = []
    for fb in firebase_users:
        email = fb.get("email") or ""
        local = db_users.get(email) or db_users.get(fb["uid"])
        disp_name = fb.get("display_name") or email or (local.username if local and local.username != str(local.id) else "Unknown")

        merged.append({
            "id": str(local.id) if local else fb["uid"],
            "username": (local.username if local else (fb.get("display_name") or email or "unknown")),
            "display_name": disp_name,
            "email": email,
            "role": (local.role if local else "user"),
            "is_active": (not fb["disabled"]) if not local else local.is_active,
            "avatar_base64": (local.avatar_base64 if local else fb.get("photo_url")),
            "created_at": (
                local.created_at.isoformat() if local and local.created_at
                else (_ms_to_iso(fb["created_at"]) if fb.get("created_at") else None)
            ),
            "last_login": (
                local.last_login.isoformat() if local and local.last_login
                else (_ms_to_iso(fb["last_sign_in"]) if fb.get("last_sign_in") else None)
            ),
            "provider": fb.get("provider", "unknown"),
            "source": "firebase",
        })

    # Include local-only users (e.g., "anonymous", synced users) that aren't in Firebase
    for username, u in db_users.items():
        if not any(m["username"] == username or m["id"] == str(u.id) for m in merged):
            disp = u.username if u.username != str(u.id) else (u.email or "Unknown")
            merged.append({
                "id": str(u.id),
                "username": u.username,
                "display_name": disp,
                "email": u.email,
                "role": u.role,
                "is_active": u.is_active,
                "avatar_base64": u.avatar_base64,
                "created_at": u.created_at.isoformat() if u.created_at else None,
                "last_login": u.last_login.isoformat() if u.last_login else None,
                "provider": "local",
                "source": "postgres",
            })

    if search:
        s = search.lower()
        merged = [m for m in merged if
                  s in (m["username"] or "").lower() or
                  s in (m.get("display_name") or "").lower() or
                  s in (m["email"] or "").lower()]

    return merged


def _ms_to_iso(ms):
    """Convert a Firebase millisecond timestamp to an ISO string."""
    from datetime import datetime, timezone
    try:
        return datetime.fromtimestamp(int(ms) / 1000, tz=timezone.utc).isoformat()
    except Exception:
        return None