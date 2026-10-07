"""
All DB query helpers. Routes call these — never raw SQL in main.py.
"""

from datetime import datetime
from typing import Optional, List

from sqlalchemy.orm import Session
from sqlalchemy import desc

from models import (
    User, Paper, Citation, ChatConversation, ChatMessage, ScopingSession,
    Search, SearchResult,
)


# ============================================================
# USERS
# ============================================================

def get_user_by_firebase_uid(db: Session, firebase_uid: str) -> Optional[User]:
    # New User model uses `username` — treat firebase_uid as username.
    return db.query(User).filter(User.username == firebase_uid).first()


def upsert_user(db: Session, firebase_uid: str, email: str = None,
                display_name: str = None, role: str = None) -> User:
    user = get_user_by_firebase_uid(db, firebase_uid)
    if user is None:
        user = User(
            username=firebase_uid,
            email=email,
            password_hash="placeholder-no-login",
            role=role or "user",
            is_active=True,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    return user


# ============================================================
# PAPERS (saved library)
# ============================================================

def list_papers(db: Session, user_id: str, status: Optional[str] = None) -> List[Paper]:
    q = db.query(Paper).filter(Paper.user_id == user_id)
    if status and status != "all":
        q = q.filter(Paper.status == status)
    return q.order_by(desc(Paper.created_at)).all()


def save_paper(db: Session, user_id: str, data: dict) -> Paper:
    paper = Paper(user_id=user_id, **data)
    db.add(paper)
    db.commit()
    db.refresh(paper)
    return paper


def delete_paper(db: Session, paper_id: str, user_id: str) -> bool:
    row = db.query(Paper).filter(Paper.id == paper_id, Paper.user_id == user_id).first()
    if not row:
        return False
    db.delete(row)
    db.commit()
    return True


def toggle_favorite_paper(db: Session, paper_id: str, user_id: str) -> Optional[Paper]:
    row = db.query(Paper).filter(Paper.id == paper_id, Paper.user_id == user_id).first()
    if not row:
        return None
    row.is_favorite = not row.is_favorite
    db.commit()
    db.refresh(row)
    return row


def update_paper_status(db: Session, paper_id: str, user_id: str,
                        status: str, progress: float = None) -> Optional[Paper]:
    row = db.query(Paper).filter(Paper.id == paper_id, Paper.user_id == user_id).first()
    if not row:
        return None
    row.status = status
    if progress is not None:
        row.progress = progress
    db.commit()
    db.refresh(row)
    return row


# ============================================================
# CITATIONS
# ============================================================

def save_citation(db: Session, user_id: str, data: dict) -> Citation:
    c = Citation(user_id=user_id, **data)
    db.add(c)
    db.commit()
    db.refresh(c)
    return c


def list_citations(db: Session, user_id: str) -> List[Citation]:
    return (db.query(Citation)
              .filter(Citation.user_id == user_id)
              .order_by(desc(Citation.created_at))
              .all())


def delete_citation(db: Session, citation_id: str, user_id: str) -> bool:
    row = db.query(Citation).filter(
        Citation.id == citation_id, Citation.user_id == user_id
    ).first()
    if not row:
        return False
    db.delete(row)
    db.commit()
    return True


# ============================================================
# CHAT
# ============================================================

def create_conversation(db: Session, user_id: str,
                        title: str = "New Conversation",
                        paper_id: Optional[str] = None) -> ChatConversation:
    conv = ChatConversation(user_id=user_id, title=title, paper_id=paper_id)
    db.add(conv)
    db.commit()
    db.refresh(conv)
    return conv


def list_conversations(db: Session, user_id: str,
                       include_archived: bool = False) -> List[ChatConversation]:
    q = db.query(ChatConversation).filter(ChatConversation.user_id == user_id)
    if not include_archived:
        q = q.filter(ChatConversation.archived_at.is_(None))
    return q.order_by(desc(ChatConversation.updated_at)).all()


def get_conversation(db: Session, conv_id: str, user_id: str) -> Optional[ChatConversation]:
    return (db.query(ChatConversation)
              .filter(ChatConversation.id == conv_id,
                      ChatConversation.user_id == user_id)
              .first())


def delete_conversation(db: Session, conv_id: str, user_id: str) -> bool:
    conv = get_conversation(db, conv_id, user_id)
    if not conv:
        return False
    db.delete(conv)
    db.commit()
    return True


def rename_conversation(db: Session, conv_id: str, user_id: str,
                        new_title: str) -> Optional[ChatConversation]:
    conv = get_conversation(db, conv_id, user_id)
    if not conv:
        return None
    conv.title = new_title
    db.commit()
    db.refresh(conv)
    return conv


def add_message(db: Session, conv_id: str, role: str, content: str,
                sources: Optional[list] = None) -> ChatMessage:
    msg = ChatMessage(
        conversation_id=conv_id,
        role=role,
        content=content,
        sources=sources,
    )
    db.add(msg)
    db.commit()
    db.refresh(msg)
    return msg


def get_messages(db: Session, conv_id: str) -> List[ChatMessage]:
    return (db.query(ChatMessage)
              .filter(ChatMessage.conversation_id == conv_id)
              .order_by(ChatMessage.created_at.asc())
              .all())


def rate_message(db: Session, message_id: str, rating: int) -> Optional[ChatMessage]:
    msg = db.query(ChatMessage).filter(ChatMessage.id == message_id).first()
    if not msg:
        return None
    msg.user_rating = rating
    db.commit()
    db.refresh(msg)
    return msg


def search_messages(db: Session, user_id: str, query: str, limit: int = 20) -> List[ChatMessage]:
    return (db.query(ChatMessage)
              .join(ChatConversation, ChatMessage.conversation_id == ChatConversation.id)
              .filter(ChatConversation.user_id == user_id)
              .filter(ChatMessage.content.ilike(f"%{query}%"))
              .order_by(desc(ChatMessage.created_at))
              .limit(limit)
              .all())


# ============================================================
# SCOPING
# ============================================================

def create_scoping(db: Session, user_id: str, raw_topic: str) -> ScopingSession:
    s = ScopingSession(user_id=user_id, raw_topic=raw_topic)
    db.add(s)
    db.commit()
    db.refresh(s)
    return s


def update_scoping(db: Session, session_id: str, user_id: str,
                   **fields) -> Optional[ScopingSession]:
    s = (db.query(ScopingSession)
           .filter(ScopingSession.id == session_id,
                   ScopingSession.user_id == user_id)
           .first())
    if not s:
        return None
    for k, v in fields.items():
        if hasattr(s, k) and v is not None:
            setattr(s, k, v)
    db.commit()
    db.refresh(s)
    return s


def complete_scoping(db: Session, session_id: str, user_id: str,
                     research_question: str) -> Optional[ScopingSession]:
    s = (db.query(ScopingSession)
           .filter(ScopingSession.id == session_id,
                   ScopingSession.user_id == user_id)
           .first())
    if not s:
        return None
    s.research_question = research_question
    s.status = "completed"
    s.completed_at = datetime.utcnow()
    db.commit()
    db.refresh(s)
    return s


def list_scopings(db: Session, user_id: str) -> List[ScopingSession]:
    return (db.query(ScopingSession)
              .filter(ScopingSession.user_id == user_id)
              .order_by(desc(ScopingSession.updated_at))
              .all())


def delete_scoping(db: Session, session_id: str, user_id: str) -> bool:
    s = (db.query(ScopingSession)
           .filter(ScopingSession.id == session_id,
                   ScopingSession.user_id == user_id)
           .first())
    if not s:
        return False
    db.delete(s)
    db.commit()
    return True


# ============================================================
# LITERATURE SEARCH (searches + search_results tables)
# ============================================================

def create_search(
    db: Session,
    user_id: str,
    topic: str,
    boolean_query: str = "",
    keywords: list = None,
    synonyms: list = None,
    date_range: str = None,
    discipline: str = None,
) -> Search:
    s = Search(
        user_id=user_id,
        topic=topic,
        boolean_query=boolean_query,
        keywords=keywords or [],
        synonyms=synonyms or [],
        date_range=date_range,
        discipline=discipline,
    )
    db.add(s)
    db.commit()
    db.refresh(s)
    return s


def add_search_results(db: Session, search_id: str, papers: list) -> int:
    rows = [
        SearchResult(
            search_id=search_id,
            external_id=p.get("id", ""),
            title=p["title"],
            authors=p.get("authors"),
            year=p.get("year"),
            abstract=p.get("abstract"),
            url=p.get("url"),
            venue=p.get("venue"),
            citations=p.get("citations", 0),
            ai_summary=p.get("ai_summary", ""),
            source=p.get("source", "Semantic Scholar"),
        )
        for p in papers
    ]
    db.add_all(rows)

    s = db.query(Search).filter(Search.id == search_id).first()
    if s:
        s.result_count = len(rows)

    db.commit()
    return len(rows)


def list_searches(db: Session, user_id: str, limit: int = 20) -> list:
    return (
        db.query(Search)
        .filter(Search.user_id == user_id)
        .order_by(desc(Search.created_at))
        .limit(limit)
        .all()
    )


def get_search(db: Session, search_id: str, user_id: str):
    return (
        db.query(Search)
        .filter(Search.id == search_id, Search.user_id == user_id)
        .first()
    )


def get_search_results(db: Session, search_id: str) -> list:
    return (
        db.query(SearchResult)
        .filter(SearchResult.search_id == search_id)
        .order_by(desc(SearchResult.citations))
        .all()
    )


def delete_search(db: Session, search_id: str, user_id: str) -> bool:
    s = get_search(db, search_id, user_id)
    if not s:
        return False
    db.delete(s)
    db.commit()
    return True