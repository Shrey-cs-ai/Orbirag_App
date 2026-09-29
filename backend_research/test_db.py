print(">>> test_db.py starting...")

import os
from pathlib import Path

print(">>> Loading .env")
env_path = Path(__file__).resolve().parent / ".env"
print(f">>> env path: {env_path}")
print(f">>> exists: {env_path.exists()}")

if env_path.exists():
    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ[k.strip()] = v.strip()

print(f">>> DATABASE_URL = {os.getenv('DATABASE_URL')}")
print(f">>> DUCKDB_PATH = {os.getenv('DUCKDB_PATH')}")

print(">>> Importing database...")
from database import engine, init_db, SessionLocal
from sqlalchemy import text

print(">>> Testing Postgres connection...")
with engine.connect() as conn:
    version = conn.execute(text("SELECT version();")).fetchone()[0]
    print(f">>> ✅ Connected: {version[:60]}")

print(">>> Importing models...")
import models
print(f">>> ✅ {len(models.Base.metadata.tables)} tables loaded:")
for t in sorted(models.Base.metadata.tables.keys()):
    print(f"      • {t}")

print(">>> Importing db_queries...")
import db_queries as q
print(">>> ✅ db_queries imported")

print(">>> Testing user insert...")
db = SessionLocal()
user = q.upsert_user(db, firebase_uid="test-uid-001",
                     email="test@example.com", display_name="Test")
print(f">>> ✅ User created: {user.id}")
db.delete(user)
db.commit()
db.close()
print(">>> ✅ Cleaned up")

print("\n🎉 Database layer is 100% working!")