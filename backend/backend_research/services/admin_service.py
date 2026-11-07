"""Read-only queries powering the admin dashboard. Never returns research content."""
from datetime import datetime, timedelta
from typing import Optional
from sqlalchemy import func
from sqlalchemy.orm import Session

from models.admin_models import (
    Institution, Student, UsageEvent, AuditLog, Invitation, StudentLoginLog,
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
    if not institution_id:
        return {
            "total_licensed_students": 0,
            "total_licenses_used": 0,
            "active_students": 0,
            "active_students_last_30_days": 0,
            "active_this_week": 0,
            "new_users_this_month": 0,
            "pending_invitations_count": 0,
            "logged_in_this_month": 0,
            "never_logged_in": 0,
            "weekly_trend": [0.0, 0.0, 0.0, 0.0],
            "top_activities": [],
            "research_projects": 0,
            "papers_analyzed": 0,
            "gap_analyses": 0,
            "gap_analysis": 0,
            "ai_citation_checks": 0,
            "citation_checks": 0,
            "literature_search": 0,
        }

    # 1. Students strictly in this institution
    inst_students_q = db.query(Student).filter(Student.institution_id == institution_id)
    total = inst_students_q.count()
    active_q = inst_students_q.filter(Student.status == "active")
    active = active_q.count()

    since_7 = datetime.utcnow() - timedelta(days=7)
    since_30 = datetime.utcnow() - timedelta(days=30)
    active_week = active_q.filter(Student.last_active_at >= since_7).count()
    active_30 = active_q.filter(Student.last_active_at >= since_30).count()
    new_month = inst_students_q.filter(Student.created_at >= since_30).count()

    now = datetime.utcnow()
    pending_invites = db.query(Invitation).filter(
        Invitation.institution_id == institution_id,
        Invitation.status == "pending",
        Invitation.expires_at > now,
    ).count()

    # 2. Usage events strictly by students belonging to this institution
    inst_uq = (
        db.query(UsageEvent)
        .join(Student, UsageEvent.student_id == Student.id)
        .filter(Student.institution_id == institution_id)
    )
    papers = inst_uq.filter(UsageEvent.event_type == "paper_analysis").count()
    gaps = inst_uq.filter(UsageEvent.event_type.in_(["gap_analysis", "gap_analyses"])).count()
    checks = inst_uq.filter(UsageEvent.event_type.in_(
        ["citation_check", "plagiarism_check", "citation_generation", "ai_citation_checks"]
    )).count()
    projects = inst_uq.filter(UsageEvent.event_type == "research_project").count()
    lit_searches = inst_uq.filter(UsageEvent.event_type.in_(["literature_search", "literature_retrieval"])).count()

    # 3. Weekly active students trend points (last 4 weeks) for real-time graph
    # Combines login and usage activity strictly for students of this institution
    weekly_trend = []
    for i in range(3, -1, -1):
        w_start = now - timedelta(days=(i + 1) * 7)
        w_end = now - timedelta(days=i * 7)
        uq_w = (
            db.query(UsageEvent.student_id)
            .join(Student, UsageEvent.student_id == Student.id)
            .filter(
                Student.institution_id == institution_id,
                UsageEvent.created_at >= w_start,
                UsageEvent.created_at < w_end,
            )
        )
        lq_w = (
            db.query(StudentLoginLog.student_id)
            .join(Student, StudentLoginLog.student_id == Student.id)
            .filter(
                Student.institution_id == institution_id,
                StudentLoginLog.login_time >= w_start,
                StudentLoginLog.login_time < w_end,
            )
        )
        cnt = uq_w.union(lq_w).count()
        weekly_trend.append(float(cnt))

    if weekly_trend[-1] == 0 and active_week > 0:
        weekly_trend[-1] = float(active_week)

    # 4. Top 3 real research activities strictly for this institution
    top_rows = (
        db.query(UsageEvent.event_type, func.count(UsageEvent.id).label("cnt"))
        .join(Student, UsageEvent.student_id == Student.id)
        .filter(Student.institution_id == institution_id)
        .group_by(UsageEvent.event_type)
        .order_by(func.count(UsageEvent.id).desc())
        .limit(3)
        .all()
    )
    top_activities = [
        {"event_type": r[0], "count": int(r[1])}
        for r in top_rows
    ]

    # 5. Login activity strictly for this institution
    inst_student_ids_query = db.query(Student.id).filter(
        Student.institution_id == institution_id,
        Student.status == "active",
    )
    logged_in_count = (
        db.query(func.count(func.distinct(StudentLoginLog.student_id)))
        .filter(
            StudentLoginLog.student_id.in_(inst_student_ids_query),
            StudentLoginLog.login_time >= since_30,
        )
        .scalar()
        or 0
    )
    never_logged_in = max(0, active - logged_in_count)

    return {
        "total_licensed_students": total,
        "total_licenses_used": active,
        "active_students": active,
        "active_students_last_30_days": active_30,
        "active_this_week": active_week,
        "new_users_this_month": new_month,
        "pending_invitations_count": pending_invites,
        "logged_in_this_month": logged_in_count,
        "never_logged_in": never_logged_in,
        "weekly_trend": weekly_trend,
        "top_activities": top_activities,
        "research_projects": projects,
        "papers_analyzed": papers,
        "gap_analyses": gaps,
        "gap_analysis": gaps,
        "ai_citation_checks": checks,
        "citation_checks": checks,
        "literature_search": lit_searches,
    }


def feature_adoption(db: Session, institution_id: Optional[int]) -> dict:
    """Return real % of active students who used each feature at least once."""
    if not institution_id:
        return {
            key: {
                "unique_users": 0,
                "total_active": 0,
                "adoption_pct": 0.0,
            }
            for key in FEATURE_KEYS
        }

    sq = db.query(Student).filter(
        Student.status == "active",
        Student.institution_id == institution_id,
    )
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
                Student.institution_id == institution_id,
                Student.status == "active",
                UsageEvent.event_type.in_(keys),
            )
        )
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
    if not institution_id:
        return out
    now = datetime.utcnow()
    for i in range(months - 1, -1, -1):
        year = now.year
        month = now.month - i
        while month <= 0:
            month += 12; year -= 1
        start = datetime(year, month, 1)
        end = datetime(year + (month == 12), (month % 12) + 1, 1)
        q = (
            db.query(func.count(func.distinct(UsageEvent.student_id)))
            .join(Student, UsageEvent.student_id == Student.id)
            .filter(
                Student.institution_id == institution_id,
                UsageEvent.created_at >= start,
                UsageEvent.created_at < end,
            )
        )
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