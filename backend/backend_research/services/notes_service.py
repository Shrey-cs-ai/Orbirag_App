from typing import List, Optional
from uuid import UUID
from sqlalchemy.orm import Session
from sqlalchemy import or_, desc

from models import Note
from schemas import NoteCreate, NoteUpdate


def create_note(db: Session, data: NoteCreate) -> Note:
    title = (data.title or "").strip() or "Untitled"
    note = Note(
        title=title,
        content=data.content or "",
        user_id=data.user_id,
    )
    db.add(note)
    db.commit()
    db.refresh(note)
    return note


def list_notes(
    db: Session,
    user_id: Optional[str] = None,
    search: Optional[str] = None,
) -> List[Note]:
    q = db.query(Note)

    if user_id:
        q = q.filter(Note.user_id == user_id)

    if search:
        pattern = f"%{search.lower()}%"
        q = q.filter(
            or_(
                Note.title.ilike(pattern),
                Note.content.ilike(pattern),
            )
        )

    q = q.order_by(desc(Note.is_pinned), desc(Note.updated_at))
    return q.all()


def get_note(db: Session, note_id: UUID) -> Optional[Note]:
    return db.query(Note).filter(Note.id == note_id).first()


def update_note(db: Session, note_id: UUID, data: NoteUpdate) -> Optional[Note]:
    note = get_note(db, note_id)
    if not note:
        return None

    if data.title is not None:
        note.title = data.title.strip() or "Untitled"
    if data.content is not None:
        note.content = data.content
    if data.is_pinned is not None:
        note.is_pinned = data.is_pinned

    db.commit()
    db.refresh(note)
    return note


def toggle_pin(db: Session, note_id: UUID) -> Optional[Note]:
    note = get_note(db, note_id)
    if not note:
        return None
    note.is_pinned = not note.is_pinned
    db.commit()
    db.refresh(note)
    return note


def delete_note(db: Session, note_id: UUID) -> bool:
    note = get_note(db, note_id)
    if not note:
        return False
    db.delete(note)
    db.commit()
    return True