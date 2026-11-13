import uuid
from datetime import datetime
from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from sqlalchemy import or_

from models import ChatConversation, ChatMessage


def list_conversations(
    db: Session,
    user_id: Optional[str] = None,
    session_type: Optional[str] = None,
) -> List[dict]:
    """
    Returns list of conversations filtered by user_id and/or session_type,
    sorted by most recently updated.
    """
    query = db.query(ChatConversation).filter(ChatConversation.archived_at == None)

    if user_id and user_id.strip():
        uid = user_id.strip()
        query = query.filter(ChatConversation.user_id == uid)

    if session_type and session_type.strip():
        query = query.filter(ChatConversation.session_type == session_type.strip())

    conversations = query.order_by(ChatConversation.updated_at.desc()).all()
    results = []

    for conv in conversations:
        # Determine clean title: if default, use first user message
        title = conv.title
        if not title or title.strip() == "New Conversation":
            first_msg = (
                db.query(ChatMessage)
                .filter(ChatMessage.conversation_id == conv.id, ChatMessage.role == "user")
                .order_by(ChatMessage.created_at.asc())
                .first()
            )
            if first_msg and first_msg.content:
                clean_content = first_msg.content.strip().split("\n")[0]
                title = clean_content[:45] + ("..." if len(clean_content) > 45 else "")
            else:
                title = "New Conversation"

        results.append({
            "id": str(conv.id),
            "title": title,
            "session_type": conv.session_type or "ori_chat",
            "paper_id": str(conv.paper_id) if conv.paper_id else None,
            "message_count": conv.message_count or 0,
            "created_at": conv.created_at.isoformat() if conv.created_at else None,
            "updated_at": conv.updated_at.isoformat() if conv.updated_at else None,
        })

    return results


def get_conversation(
    db: Session,
    conversation_id: str,
    user_id: Optional[str] = None,
) -> Optional[dict]:
    """
    Returns a conversation and its messages.
    """
    query = db.query(ChatConversation).filter(ChatConversation.id == conversation_id)
    if user_id and user_id.strip():
        query = query.filter(
            or_(
                ChatConversation.user_id == user_id.strip(),
                ChatConversation.user_id == None,
            )
        )
    conv = query.first()
    if not conv:
        return None

    messages = (
        db.query(ChatMessage)
        .filter(ChatMessage.conversation_id == conv.id)
        .order_by(ChatMessage.created_at.asc())
        .all()
    )

    return {
        "id": str(conv.id),
        "title": conv.title,
        "session_type": conv.session_type or "ori_chat",
        "paper_id": str(conv.paper_id) if conv.paper_id else None,
        "message_count": conv.message_count or len(messages),
        "created_at": conv.created_at.isoformat() if conv.created_at else None,
        "updated_at": conv.updated_at.isoformat() if conv.updated_at else None,
        "messages": [
            {
                "id": str(m.id),
                "role": m.role,
                "content": m.content,
                "sources": m.sources,
                "created_at": m.created_at.isoformat() if m.created_at else None,
            }
            for m in messages
        ],
    }


def delete_conversation(
    db: Session,
    conversation_id: str,
    user_id: Optional[str] = None,
) -> bool:
    """
    Deletes conversation and cascades to messages.
    """
    query = db.query(ChatConversation).filter(ChatConversation.id == conversation_id)
    if user_id and user_id.strip():
        query = query.filter(
            or_(
                ChatConversation.user_id == user_id.strip(),
                ChatConversation.user_id == None,
            )
        )
    conv = query.first()
    if not conv:
        return False

    db.delete(conv)
    db.commit()
    return True


def record_chat_turn(
    db: Session,
    user_message: str,
    assistant_message: str,
    session_type: str = "ori_chat",
    conversation_id: Optional[str] = None,
    user_id: Optional[str] = None,
    paper_id: Optional[str] = None,
    sources: Optional[list] = None,
) -> Tuple[ChatConversation, ChatMessage, ChatMessage]:
    """
    Finds or creates a conversation and appends both user and assistant messages.
    """
    conv = None
    if conversation_id and conversation_id.strip():
        conv = db.query(ChatConversation).filter(ChatConversation.id == conversation_id.strip()).first()

    now = datetime.utcnow()
    clean_title = user_message.strip().split("\n")[0][:50]
    if len(clean_title) >= 50:
        clean_title += "..."

    if not conv:
        conv = ChatConversation(
            id=str(uuid.uuid4()),
            user_id=user_id.strip() if user_id else None,
            session_type=session_type,
            title=clean_title or "New Conversation",
            paper_id=paper_id,
            message_count=0,
            created_at=now,
            updated_at=now,
        )
        db.add(conv)
        db.flush()
    else:
        # If title is default, update with first user message
        if conv.title == "New Conversation" or not conv.title:
            conv.title = clean_title
        conv.updated_at = now

    user_msg = ChatMessage(
        id=str(uuid.uuid4()),
        conversation_id=conv.id,
        role="user",
        content=user_message,
        sources=None,
        created_at=now,
    )
    db.add(user_msg)

    asst_msg = ChatMessage(
        id=str(uuid.uuid4()),
        conversation_id=conv.id,
        role="assistant",
        content=assistant_message,
        sources=sources,
        created_at=datetime.utcnow(),
    )
    db.add(asst_msg)

    conv.message_count = (conv.message_count or 0) + 2
    db.commit()
    db.refresh(conv)

    return conv, user_msg, asst_msg

