"""Read-only queries powering the admin dashboard. Never returns research content."""
from datetime import datetime, timedelta
from typing import Optional
from sqlalchemy import func
from sqlalchemy.orm import Session

from models.admin_models import (
    Institution, Student, UsageEvent, AuditLog,
)


FEATURE_KEYS = [
    "literature_search",
    "gap_analysis",
    "citation_check",
    "plagiarism_check",
    "methodology_builder",
    "ai_writing",
    "paper_analysis",
    "research_project",
]


def dashboard_summary(db: Session, institution_id: Optional[int]) -> dict:
    q = db.query(Student)
    if institution_id:
        q = q.filter(Student.institution_id == institution_id)
    total = q.count()
    active = q.filter(Student.status == "active").count()

    since_7 = datetime.utcnow() - timedelta(days=7)
    since_30 = datetime.utcnow() - timedelta(days=30)
    active_week = q.filter(Student.last_active_at >= since_7).count()
    new_month = q.filter(Student.created_at >= since_30).count()

    uq = db.query(UsageEvent)
    if institution_id:
        uq = uq.filter(UsageEvent.institution_id == institution_id)
    papers = uq.filter(UsageEvent.event_type == "paper_analysis").count()
    gaps = uq.filter(UsageEvent.event_type == "gap_analysis").count()
    checks = uq.filter(UsageEvent.event_type.in_(
        ["citation_check", "plagiarism_check"])).count()
    projects = uq.filter(UsageEvent.event_type == "research_project").count()

    return {
        "total_licensed_students": total,
        "active_students": active,
        "active_this_week": active_week,
        "new_users_this_month": new_month,
        "research_projects": projects,
        "papers_analyzed": papers,
        "gap_analyses": gaps,
        "ai_citation_checks": checks,
    }


def feature_adoption(db: Session, institution_id: Optional[int]) -> dict:
    """Return % of active students who used each feature at least once."""
    sq = db.query(Student).filter(Student.status == "active")
    if institution_id:
        sq = sq.filter(Student.institution_id == institution_id)
    total_active = sq.count() or 1

    result = {}
    for key in FEATURE_KEYS:
        uq = db.query(func.count(func.distinct(UsageEvent.student_id))).filter(
            UsageEvent.event_type == key
        )
        if institution_id:
            uq = uq.filter(UsageEvent.institution_id == institution_id)
        used = uq.scalar() or 0
        result[key] = {
            "unique_users": used,
            "adoption_pct": round(100.0 * used / total_active, 1),
        }
    return result


def monthly_active(db: Session, institution_id: Optional[int], months: int = 6) -> list:
    """Monthly active users for the last N months."""
    out = []
    now = datetime.utcnow()
    for i in range(months - 1, -1, -1):
        # naive month math
        year = now.year
        month = now.month - i
        while month <= 0:
            month += 12; year -= 1
        start = datetime(year, month, 1)
        end = datetime(year + (month == 12), (month % 12) + 1, 1)
        q = db.query(func.count(func.distinct(UsageEvent.student_id))).filter(
            UsageEvent.created_at >= start, UsageEvent.created_at < end
        )
        if institution_id:
            q = q.filter(UsageEvent.institution_id == institution_id)
        out.append({"month": f"{year}-{month:02d}", "active_users": q.scalar() or 0})
    return out


def student_usage_summary(db: Session, student_id: int) -> dict:
    """Counts only — no content."""
    counts = {}
    for key in FEATURE_KEYS:
        counts[key] = db.query(UsageEvent).filter(
            UsageEvent.student_id == student_id,
            UsageEvent.event_type == key,
        ).count()
    last = db.query(UsageEvent).filter(
        UsageEvent.student_id == student_id
    ).order_by(UsageEvent.created_at.desc()).first()
    return {
        "counts": counts,
        "last_active": last.created_at.isoformat() if last else None,
    }


def log_action(db: Session, admin_id: Optional[int], institution_id: Optional[int],
               action: str, target_student_id: Optional[int] = None,
               details: Optional[str] = None) -> None:
    db.add(AuditLog(
        admin_id=admin_id,
        institution_id=institution_id,
        action=action,
        target_student_id=target_student_id,
        details=details,
    ))
    db.commit()