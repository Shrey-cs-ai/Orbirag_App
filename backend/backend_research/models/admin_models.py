"""Admin dashboard models — privacy-preserving institutional control."""
from datetime import datetime
from sqlalchemy import (
    Column, Integer, String, Text, Boolean, DateTime, ForeignKey
)
from database import Base  # adjust if your Base is elsewhere


class Institution(Base):
    __tablename__ = "institutions"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    plan = Column(String(64), default="campus_pro")
    license_limit = Column(Integer, default=2500)
    subscription_status = Column(String(32), default="active")
    renewal_date = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class AdminUser(Base):
    __tablename__ = "admin_users"
    id = Column(Integer, primary_key=True, index=True)
    institution_id = Column(Integer, ForeignKey("institutions.id"), nullable=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    name = Column(String(255))
    password_hash = Column(String(255), nullable=False)
    role = Column(String(32), default="institution_admin")  # institution_admin | super_admin
    created_at = Column(DateTime, default=datetime.utcnow)
    last_login_at = Column(DateTime, nullable=True)


class AdminSession(Base):
    __tablename__ = "admin_sessions"
    id = Column(Integer, primary_key=True, index=True)
    admin_id = Column(Integer, ForeignKey("admin_users.id"), nullable=False, index=True)
    token = Column(String(255), unique=True, nullable=False, index=True)
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)


class Student(Base):
    __tablename__ = "students"
    id = Column(Integer, primary_key=True, index=True)
    institution_id = Column(Integer, ForeignKey("institutions.id"), nullable=True, index=True)
    external_uid = Column(String(255), unique=True, nullable=True, index=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    name = Column(String(255))
    photo_url = Column(String(1024), nullable=True)
    role = Column(String(32), default="student")
    status = Column(String(32), default="active")  # active | suspended | banned
    ban_reason = Column(Text, nullable=True)
    banned_by = Column(Integer, ForeignKey("admin_users.id"), nullable=True)
    banned_at = Column(DateTime, nullable=True)
    suspended_until = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_active_at = Column(DateTime, nullable=True)


class StudentLoginLog(Base):
    __tablename__ = "student_login_logs"
    id = Column(Integer, primary_key=True, index=True)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=True, index=True)
    email = Column(String(255), nullable=False, index=True)
    login_time = Column(DateTime, default=datetime.utcnow, index=True)
    status = Column(String(32), nullable=False)  # "success" or "blocked"


class UsageEvent(Base):
    """Aggregated event log. Deliberately NO research content stored."""
    __tablename__ = "usage_events"
    id = Column(Integer, primary_key=True, index=True)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=True, index=True)
    institution_id = Column(Integer, ForeignKey("institutions.id"), nullable=True, index=True)
    event_type = Column(String(64), nullable=False, index=True)
    # event_type: research_project | paper_analysis | gap_analysis |
    #             citation_check | literature_search | plagiarism_check |
    #             methodology_builder | ai_writing
    created_at = Column(DateTime, default=datetime.utcnow, index=True)


class AuditLog(Base):
    __tablename__ = "audit_logs"
    id = Column(Integer, primary_key=True, index=True)
    admin_id = Column(Integer, ForeignKey("admin_users.id"), nullable=True, index=True)
    institution_id = Column(Integer, ForeignKey("institutions.id"), nullable=True)
    action = Column(String(64), nullable=False)  # login|logout|ban|unban|suspend|reset_password|role_change
    target_student_id = Column(Integer, ForeignKey("students.id"), nullable=True)
    details = Column(Text, nullable=True)  # JSON string, no sensitive content
    created_at = Column(DateTime, default=datetime.utcnow, index=True)