from typing import List, Optional
from uuid import UUID
from sqlalchemy.orm import Session
from sqlalchemy import or_, desc

from models import LibraryItem
from schemas import LibraryItemCreate, LibraryItemUpdate


def create_item(db: Session, data: LibraryItemCreate) -> LibraryItem:
    item = LibraryItem(
        title=data.title.strip(),
        description=data.description.strip(),
        type=data.type,
        user_id=data.user_id,
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


def list_items(
    db: Session,
    user_id: Optional[str] = None,
    search: Optional[str] = None,
) -> List[LibraryItem]:
    q = db.query(LibraryItem)

    if user_id:
        q = q.filter(LibraryItem.user_id == user_id)

    if search:
        pattern = f"%{search.lower()}%"
        q = q.filter(
            or_(
                LibraryItem.title.ilike(pattern),
                LibraryItem.description.ilike(pattern),
                LibraryItem.type.ilike(pattern),
            )
        )

    q = q.order_by(desc(LibraryItem.is_pinned), desc(LibraryItem.created_at))
    return q.all()


def get_item(db: Session, item_id: UUID) -> Optional[LibraryItem]:
    return db.query(LibraryItem).filter(LibraryItem.id == item_id).first()


def update_item(db: Session, item_id: UUID, data: LibraryItemUpdate) -> Optional[LibraryItem]:
    item = get_item(db, item_id)
    if not item:
        return None

    if data.title is not None:
        item.title = data.title.strip()
    if data.description is not None:
        item.description = data.description.strip()
    if data.is_pinned is not None:
        item.is_pinned = data.is_pinned

    db.commit()
    db.refresh(item)
    return item


def toggle_pin(db: Session, item_id: UUID) -> Optional[LibraryItem]:
    item = get_item(db, item_id)
    if not item:
        return None
    item.is_pinned = not item.is_pinned
    db.commit()
    db.refresh(item)
    return item


def delete_item(db: Session, item_id: UUID) -> bool:
    item = get_item(db, item_id)
    if not item:
        return False
    db.delete(item)
    db.commit()
    return True