"""Read-only queries powering the admin dashboard. Never returns research content."""
from datetime import datetime, timedelta
from typing import Optional
from sqlalchemy import func
from sqlalchemy.orm import Session

from models.admin_models import (
    Institution, Student, UsageEvent, AuditLog, Invitation,
)


FEATURE_KEYS = [
    "topic_scoping",
    "literature_retrieval",
    "gap_analysis",
    "paper_analysis",
    "paper_orbit",
    "ori_chatbot",
    "methodology_builder",
    "citation_generation",
    "plagiarism_check",
    "word_counter",
    "notes_writing",
    "paper_saved",
    "library_access",
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
    active_30 = q.filter(Student.last_active_at >= since_30).count()
    new_month = q.filter(Student.created_at >= since_30).count()

    now = datetime.utcnow()
    inv_q = db.query(Invitation).filter(
        Invitation.status == "pending",
        Invitation.expires_at > now,
    )
    if institution_id:
        inv_q = inv_q.filter(Invitation.institution_id == institution_id)
    pending_invites = inv_q.count()

    uq = db.query(UsageEvent)
    if institution_id:
        uq = uq.filter(UsageEvent.institution_id == institution_id)
    papers = uq.filter(UsageEvent.event_type == "paper_analysis").count()
    gaps = uq.filter(UsageEvent.event_type == "gap_analysis").count()
    checks = uq.filter(UsageEvent.event_type.in_(
        ["citation_check", "plagiarism_check"])).count()
    projects = uq.filter(UsageEvent.event_type == "research_project").count()
    lit_searches = uq.filter(UsageEvent.event_type == "literature_search").count()

    # Calculate weekly trend points (last 4 weeks) for real-time graph
    weekly_trend = []
    for i in range(3, -1, -1):
        w_start = now - timedelta(days=(i + 1) * 7)
        w_end = now - timedelta(days=i * 7)
        uq_w = db.query(func.count(func.distinct(UsageEvent.student_id))).filter(
            UsageEvent.created_at >= w_start,
            UsageEvent.created_at < w_end,
        )
        if institution_id:
            uq_w = uq_w.filter(UsageEvent.institution_id == institution_id)
        cnt = uq_w.scalar() or 0
        weekly_trend.append(float(cnt))

    if weekly_trend[-1] == 0 and active_week > 0:
        weekly_trend[-1] = float(active_week)

    # Top 3 real research activities
    top_rows = (
        db.query(UsageEvent.event_type, func.count(UsageEvent.id).label("cnt"))
        .filter(UsageEvent.institution_id == institution_id if institution_id else True)
        .group_by(UsageEvent.event_type)
        .order_by(func.count(UsageEvent.id).desc())
        .limit(3)
        .all()
    )
    top_activities = [
        {"event_type": r[0], "count": int(r[1])}
        for r in top_rows
    ]

    return {
        "total_licensed_students": total,
        "total_licenses_used": active,
        "active_students": active,
        "active_students_last_30_days": active_30,
        "active_this_week": active_week,
        "new_users_this_month": new_month,
        "pending_invitations_count": pending_invites,
        "weekly_trend": weekly_trend,
        "top_activities": top_activities,
        "research_projects": projects,
        "papers_analyzed": papers,
        "gap_analyses": gaps,
        "ai_citation_checks": checks,
        "literature_search": lit_searches,
        "citation_checks": checks,
    }
def feature_adoption(db: Session, institution_id: Optional[int]) -> dict:
    """Return real % of active students who used each feature at least once."""
    sq = db.query(Student).filter(Student.status == "active")
    if institution_id:
        sq = sq.filter(Student.institution_id == institution_id)
    total_active = sq.count()

    alias_map = {
        "literature_retrieval": ["literature_retrieval", "literature_search"],
        "citation_generation": ["citation_generation", "citation_check", "ai_citation_checks"],
        "gap_analysis": ["gap_analysis", "gap_analyses"],
        "paper_analysis": ["paper_analysis"],
        "paper_orbit": ["paper_orbit", "chat_with_pdf"],
        "notes_writing": ["notes_writing", "my_notes"],
        "topic_scoping": ["topic_scoping", "guided_topic_scoping"],
        "methodology_builder": ["methodology_builder", "methodology"],
        "plagiarism_check": ["plagiarism_check"],
        "word_counter": ["word_counter"],
        "paper_saved": ["paper_saved"],
        "library_access": ["library_access"],
        "ori_chatbot": ["ori_chatbot"],
    }

    result = {}
    for key in FEATURE_KEYS:
        keys = alias_map.get(key, [key])
        uq = (
            db.query(func.count(func.distinct(UsageEvent.student_id)))
            .join(Student, UsageEvent.student_id == Student.id)
            .filter(
                UsageEvent.event_type.in_(keys),
                Student.status == "active",
            )
        )
        if institution_id:
            uq = uq.filter(Student.institution_id == institution_id)
        used = uq.scalar() or 0
        adoption_pct = round((used / total_active) * 100.0, 1) if total_active > 0 else 0.0
        result[key] = {
            "unique_users": used,
            "total_active": total_active,
            "adoption_pct": adoption_pct,
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