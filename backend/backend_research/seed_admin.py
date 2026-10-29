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

    first = ["Shreya", "Ram", "Anisha", "Bikash", "Nisha", "Prakash",
             "Rita", "Sujan", "Aayush", "Srijana"]
    last = ["Ganeju", "Sharma", "K.", "Thapa", "Adhikari", "Rai",
            "Gurung", "KC", "Basnet", "Shrestha"]
    statuses = ["active"] * 8 + ["suspended", "banned"]
    features = ["literature_search", "gap_analysis", "citation_check",
                "plagiarism_check", "methodology_builder", "ai_writing",
                "paper_analysis", "research_project"]

    students = []
    for i in range(20):
        s = Student(
            institution_id=inst.id,
            email=f"student{i+1}@sunway.edu.np",
            name=f"{random.choice(first)} {random.choice(last)}",
            status=random.choice(statuses),
            created_at=datetime.utcnow() - timedelta(days=random.randint(10, 300)),
            last_active_at=datetime.utcnow() - timedelta(days=random.randint(0, 20)),
        )
        if s.status == "banned":
            s.ban_reason = "Institutional policy violation"
            s.banned_by = admin.id
            s.banned_at = datetime.utcnow() - timedelta(days=random.randint(1, 15))
        db.add(s); students.append(s)
    db.commit()

    # Sample usage events over the last 6 months
    now = datetime.utcnow()
    for _ in range(400):
        s = random.choice(students)
        if s.status == "banned":
            continue
        ev = UsageEvent(
            student_id=s.id,
            institution_id=inst.id,
            event_type=random.choice(features),
            created_at=now - timedelta(days=random.randint(0, 180)),
        )
        db.add(ev)
    db.commit()

    print("✅ Seed complete")
    print(f"   Institution: {inst.name} (id={inst.id})")
    print(f"   Admin login: admin@orbirag.local / admin123")
    print(f"   Students:    {len(students)}")
    print()
    print("⚠️  CHANGE THE PASSWORD after first login.")
finally:
    db.close()