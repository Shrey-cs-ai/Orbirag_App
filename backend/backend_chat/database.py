import os
from datetime import datetime
from pathlib import Path
from sqlalchemy import create_engine, Column, String, Integer, DateTime, JSON
from sqlalchemy.orm import sessionmaker, declarative_base

if hasattr(os, "add_dll_directory"):
    for pg_bin in [r"C:\Program Files\PostgreSQL\18\bin", r"C:\Program Files\PostgreSQL\17\bin", r"C:\Program Files\PostgreSQL\16\bin"]:
        if os.path.isdir(pg_bin):
            try:
                os.add_dll_directory(pg_bin)
            except Exception:
                pass

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://orbirag:orbirag@localhost:5432/orbirag_db")

try:
    engine = create_engine(
        DATABASE_URL,
        pool_pre_ping=True,
        pool_size=5,
        max_overflow=10,
        echo=False,
    )
    # Test connection quickly
    with engine.connect() as conn:
        pass
except Exception as e:
    # Fallback to local SQLite if PostgreSQL is unreachable (sandbox or offline)
    print(f"[DB] PostgreSQL unavailable ({e}), falling back to SQLite for chat backend.")
    sqlite_path = Path(__file__).resolve().parent / "chat_storage.db"
    DATABASE_URL = f"sqlite:///{sqlite_path}"
    engine = create_engine(
        DATABASE_URL,
        connect_args={"check_same_thread": False},
        echo=False,
    )

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

Base = declarative_base()


class ChatPdfDocument(Base):
    __tablename__ = "chat_pdf_documents"

    id = Column(String(64), primary_key=True)
    user_id = Column(String(128), nullable=True, index=True)
    filename = Column(String(255), nullable=False)
    chunks = Column(JSON, nullable=False)
    num_pages = Column(Integer, default=1)
    created_at = Column(DateTime, default=datetime.utcnow)


def init_db():
    Base.metadata.create_all(bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

