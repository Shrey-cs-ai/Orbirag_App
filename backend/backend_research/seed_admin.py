"""One-time seed: creates default institution, admin, and demo students.
Run once:  python seed_admin.py
"""
import random
from datetime import datetime, timedelta
from database import SessionLocal, Base, engine
from models.admin_models import (
    Institution, AdminUser, Student, UsageEvent,
)
from services.admin_auth import hash_password

# Ensure all tables exist
from models import admin_models  # noqa: F401
Base.metadata.create_all(bind=engine)

db = SessionLocal()
try:
    if db.query(Institution).first():
        print("⚠️  Seed already applied. Skipping.")
        raise SystemExit(0)

    inst = Institution(
        name="Sunway College",
        plan="campus_pro",
        license_limit=2500,
        renewal_date=datetime.utcnow() + timedelta(days=365),
    )
    db.add(inst); db.commit(); db.refresh(inst)

    admin = AdminUser(
        institution_id=inst.id,
        email="admin@orbirag.local",
        name="Campus Admin",
        password_hash=hash_password("admin123"),
        role="institution_admin",
    )
    db.add(admin); db.commit(); db.refresh(admin)

    # Only seed institution and admin user.
    # Students are added ONLY via institutional invitations.
    print("✅ Seed complete")
    print(f"   Institution: {inst.name} (id={inst.id})")
    print(f"   Admin login: admin@orbirag.local / admin123")
    print("   Students:    0 (Real invited students only)")
    print()
    print("⚠️  CHANGE THE PASSWORD after first login.")
finally:
    db.close()