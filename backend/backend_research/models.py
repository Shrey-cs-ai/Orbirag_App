"""
SQLAlchemy ORM models — mirror the Postgres tables.
Schemas (API shapes) live in schemas.py.
"""

import uuid
from datetime import datetime

from sqlalchemy import (
    Column, String, Text, Integer, Boolean, Float,
    DateTime, ForeignKey, SmallInteger, CheckConstraint, JSON, Uuid, func
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from database import Base


def _uuid():
    return str(uuid.uuid4())


# ============================================================
# PAPERS (saved library)
# ============================================================

class Paper(Base):
    __tablename__ = "papers"

    id          = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id     = Column(String(64), nullable=True, index=True)
    title       = Column(Text, nullable=False)
    authors     = Column(Text)
    year        = Column(String)
    journal     = Column(Text)
    abstract    = Column(Text)
    url         = Column(Text)
    source      = Column(Text)
    citations   = Column(Integer, default=0)
    status      = Column(String, default="unread")
    progress    = Column(Float, default=0.0)
    is_favorite = Column(Boolean, default=False)
    created_at  = Column(DateTime, default=datetime.utcnow)
    updated_at  = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        CheckConstraint("status IN ('unread','reading','analyzed')", name="papers_status_check"),
    )


# ============================================================
# CITATIONS
# ============================================================

class Citation(Base):
    __tablename__ = "citations"

    id             = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id        = Column(String(64), nullable=True, index=True)
    title          = Column(Text, nullable=False)
    authors        = Column(Text)
    year           = Column(String)
    journal        = Column(Text)
    style          = Column(String)
    source_type    = Column(String)
    in_text        = Column(Text)
    reference_list = Column(Text)
    created_at     = Column(DateTime, default=datetime.utcnow)


# ============================================================
# CHAT
# ============================================================

class ChatConversation(Base):
    __tablename__ = "chat_conversations"

    id            = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id       = Column(String(64), nullable=True, index=True)
    title         = Column(Text, default="New Conversation")
    paper_id      = Column(UUID(as_uuid=False), ForeignKey("papers.id", ondelete="SET NULL"),
                           nullable=True)
    message_count = Column(Integer, default=0)
    created_at    = Column(DateTime, default=datetime.utcnow)
    updated_at    = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    archived_at   = Column(DateTime, nullable=True)

    messages = relationship("ChatMessage", back_populates="conversation",
                            cascade="all, delete-orphan",
                            order_by="ChatMessage.created_at")


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id              = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    conversation_id = Column(UUID(as_uuid=False),
                             ForeignKey("chat_conversations.id", ondelete="CASCADE"),
                             nullable=False, index=True)
    role            = Column(String, nullable=False)
    content         = Column(Text, nullable=False)
    sources         = Column(JSON, nullable=True)
    user_rating     = Column(SmallInteger, nullable=True)
    created_at      = Column(DateTime, default=datetime.utcnow)

    conversation = relationship("ChatConversation", back_populates="messages")

    __table_args__ = (
        CheckConstraint("role IN ('user','assistant','system')", name="chat_messages_role_check"),
    )


# ============================================================
# SCOPING
# ============================================================

class ScopingSession(Base):
    __tablename__ = "scoping_sessions"

    id                = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id           = Column(String(64), nullable=True, index=True)
    raw_topic         = Column(Text, nullable=False)
    population        = Column(Text)
    intervention      = Column(Text)
    comparison        = Column(Text)
    outcome           = Column(Text)
    research_question = Column(Text)
    status            = Column(String, default="draft")
    current_step      = Column(Integer, default=0)
    created_at        = Column(DateTime, default=datetime.utcnow)
    updated_at        = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    completed_at      = Column(DateTime, nullable=True)

    __table_args__ = (
        CheckConstraint("status IN ('draft','completed','searched','archived')",
                        name="scoping_status_check"),
    )


# ============================================================
# LITERATURE SEARCH
# ============================================================

class Search(Base):
    __tablename__ = "searches"

    id            = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id       = Column(String(64), nullable=True, index=True)
    topic         = Column(Text, nullable=False)
    boolean_query = Column(Text)
    keywords      = Column(JSON)
    synonyms      = Column(JSON)
    date_range    = Column(Text)
    discipline    = Column(Text)
    result_count  = Column(Integer, default=0)
    created_at    = Column(DateTime, default=datetime.utcnow)

    results = relationship("SearchResult", back_populates="search",
                           cascade="all, delete-orphan")


class SearchResult(Base):
    __tablename__ = "search_results"

    id          = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    search_id   = Column(UUID(as_uuid=False),
                         ForeignKey("searches.id", ondelete="CASCADE"),
                         nullable=False, index=True)
    external_id = Column(Text)
    title       = Column(Text, nullable=False)
    authors     = Column(Text)
    year        = Column(String)
    abstract    = Column(Text)
    url         = Column(Text)
    venue       = Column(Text)
    citations   = Column(Integer, default=0)
    ai_summary  = Column(Text)
    source      = Column(Text, default="Semantic Scholar")
    is_saved    = Column(Boolean, default=False)
    created_at  = Column(DateTime, default=datetime.utcnow)

    search = relationship("Search", back_populates="results")


# LITERATURE SEARCH
class LibraryItem(Base):
    __tablename__ = "library_items"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id = Column(String(64), nullable=True, index=True)
    title = Column(Text, nullable=False)
    description = Column(Text, nullable=False, default="")
    type = Column(String(32), nullable=False)  # insight | draft | citation | idea | note
    is_pinned = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


#notes
class Note(Base):
    __tablename__ = "notes"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(String(64), nullable=True, index=True)
    title = Column(Text, nullable=False, default="Untitled")
    content = Column(Text, nullable=False, default="")
    is_pinned = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


#user model
class User(Base):
    __tablename__ = "users"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    username = Column(String(64), unique=True, nullable=False, index=True)
    email = Column(String(255), unique=True, nullable=True, index=True)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(16), nullable=False, default="user")   # "user" | "admin"
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    last_login = Column(DateTime(timezone=True), nullable=True)


#plagiarismCheck model
class PlagiarismCheck(Base):
    __tablename__ = "plagiarism_checks"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id = Column(String(64), nullable=True, index=True)
    document_text = Column(Text, nullable=False)
    similarity_score = Column(String(8), nullable=False)   # e.g. "18%"
    matches = Column(JSON, nullable=False, default=list)   # list of matched dicts
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class Methodology(Base):
    __tablename__ = "methodologies"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id = Column(String(64), nullable=True, index=True)
    paper_title = Column(Text, nullable=True)
    raw_text = Column(Text, nullable=False)

    study_type = Column(String(32), nullable=True)
    design = Column(Text, nullable=True)
    sample_size = Column(Text, nullable=True)
    sampling_method = Column(Text, nullable=True)
    data_collection = Column(Text, nullable=True)
    analysis_method = Column(Text, nullable=True)
    databases_searched = Column(Text, nullable=True)
    inclusion_criteria = Column(Text, nullable=True)
    exclusion_criteria = Column(Text, nullable=True)
    studies_included_count = Column(Text, nullable=True)
    additional_notes = Column(Text, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())