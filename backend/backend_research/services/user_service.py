from typing import List, Optional
from uuid import UUID
from sqlalchemy.orm import Session

from models import User
from schemas import UserCreate
from services.auth_service import hash_password


def get_by_username(db: Session, username: str) -> Optional[User]:
    return db.query(User).filter(User.username == username).first()


def get_by_id(db: Session, user_id: UUID) -> Optional[User]:
    return db.query(User).filter(User.id == user_id).first()


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