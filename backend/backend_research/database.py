"""
PostgreSQL connection via SQLAlchemy 2.0.

Notes:
- Uses SYNC engine for simplicity (fine for our scale).
- If you later need async, swap to `create_async_engine` with asyncpg.
- Reads DATABASE_URL from .env (loaded in main.py BEFORE this import).
"""

import os

if hasattr(os, "add_dll_directory"):
    for pg_bin in [r"C:\Program Files\PostgreSQL\18\bin", r"C:\Program Files\PostgreSQL\17\bin", r"C:\Program Files\PostgreSQL\16\bin"]:
        if os.path.isdir(pg_bin):
            try:
                os.add_dll_directory(pg_bin)
            except Exception:
                pass

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://orbirag:orbirag@localhost:5432/orbirag_db",
)

# echo=False in prod; flip to True when debugging SQL
engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,     # recycle dead connections
    pool_size=5,
    max_overflow=10,
    echo=False,
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

Base = declarative_base()


def get_db():
    """FastAPI dependency: yields a session, always closes."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()



    """
    Create tables if they don't exist.
    For production, use Alembic migrations instead.
    """
def init_db():
    import models  # noqa: F401
    Base.metadata.create_all(bind=engine)