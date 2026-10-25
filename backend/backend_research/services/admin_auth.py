"""Password hashing + session token management. Stdlib only."""
import hashlib
import secrets
from datetime import datetime, timedelta
from typing import Optional
from fastapi import Depends, HTTPException, Header
from sqlalchemy.orm import Session

from database import get_db
from models.admin_models import AdminUser, AdminSession


SESSION_HOURS = 12
PBKDF2_ITERATIONS = 120_000


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    key = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, PBKDF2_ITERATIONS)
    return f"{salt.hex()}${key.hex()}"


def verify_password(password: str, stored: str) -> bool:
    try:
        salt_hex, key_hex = stored.split("$")
        salt = bytes.fromhex(salt_hex)
        expected = bytes.fromhex(key_hex)
        actual = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, PBKDF2_ITERATIONS)
        return secrets.compare_digest(actual, expected)
    except Exception:
        return False


def create_session(db: Session, admin: AdminUser) -> str:
    token = secrets.token_urlsafe(48)
    sess = AdminSession(
        admin_id=admin.id,
        token=token,
        expires_at=datetime.utcnow() + timedelta(hours=SESSION_HOURS),
    )
    db.add(sess)
    admin.last_login_at = datetime.utcnow()
    db.commit()
    return token


def current_admin(
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db),
) -> AdminUser:
    """FastAPI dependency: resolves admin from `Authorization: Bearer <token>`."""
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(401, "Missing admin token")
    token = authorization.split(" ", 1)[1].strip()
    sess = db.query(AdminSession).filter(AdminSession.token == token).first()
    if not sess:
        raise HTTPException(401, "Invalid session")
    if sess.expires_at < datetime.utcnow():
        db.delete(sess); db.commit()
        raise HTTPException(401, "Session expired")
    admin = db.query(AdminUser).filter(AdminUser.id == sess.admin_id).first()
    if not admin:
        raise HTTPException(401, "Admin not found")
    return admin