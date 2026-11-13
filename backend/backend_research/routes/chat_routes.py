from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Header, Query
from sqlalchemy.orm import Session

from database import get_db
from services import chat_history_service

router = APIRouter(prefix="/api/chat", tags=["Chat History"])


@router.get("/history")
def get_chat_history(
    session_type: Optional[str] = Query(None, description="ori_chat or paper_orbit"),
    user_id: Optional[str] = Query(None, description="User ID"),
    x_user_id: Optional[str] = Header(None, alias="x-user-id"),
    db: Session = Depends(get_db),
):
    """
    Returns list of past conversations for the authenticated user.
    """
    effective_user_id = user_id or x_user_id
    conversations = chat_history_service.list_conversations(
        db,
        user_id=effective_user_id,
        session_type=session_type,
    )
    return {
        "conversations": conversations,
        "total": len(conversations),
    }


@router.get("/history/{conversation_id}")
def get_conversation_detail(
    conversation_id: str,
    user_id: Optional[str] = Query(None),
    x_user_id: Optional[str] = Header(None, alias="x-user-id"),
    db: Session = Depends(get_db),
):
    """
    Returns conversation metadata and all messages.
    """
    effective_user_id = user_id or x_user_id
    conv = chat_history_service.get_conversation(
        db,
        conversation_id=conversation_id,
        user_id=effective_user_id,
    )
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return conv


@router.delete("/history/{conversation_id}")
def delete_conversation_route(
    conversation_id: str,
    user_id: Optional[str] = Query(None),
    x_user_id: Optional[str] = Header(None, alias="x-user-id"),
    db: Session = Depends(get_db),
):
    """
    Deletes a conversation and all its messages.
    """
    effective_user_id = user_id or x_user_id
    success = chat_history_service.delete_conversation(
        db,
        conversation_id=conversation_id,
        user_id=effective_user_id,
    )
    if not success:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return {
        "deleted": True,
        "conversation_id": conversation_id,
    }

