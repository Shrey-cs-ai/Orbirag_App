"""Admin API — /api/admin/*. All routes require Bearer token except /login."""
import uuid
from datetime import datetime, timedelta
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from database import get_db
try:
    from models import User
except Exception:
    User = None
from models.admin_models import (
    Institution, AdminUser, AdminSession, Student, UsageEvent, StudentLoginLog, Invitation,
)
from services import admin_auth as auth
from services import admin_service as svc

router = APIRouter(prefix="/api/admin", tags=["admin"])


# ---------------- Schemas ----------------
class LoginRequest(BaseModel):
    email: str
    password: str


class StatusRequest(BaseModel):
    status: str                # active | suspended | banned
    reason: Optional[str] = None
    suspend_days: Optional[int] = None


class RecordUsageRequest(BaseModel):
    student_external_uid: Optional[str] = None
    student_email: Optional[str] = None
    event_type: str


class RegisterStudentRequest(BaseModel):
    external_uid: Optional[str] = None
    email: str
    name: Optional[str] = None



class InviteStudentRequest(BaseModel):
    email: str
    role: str = "student"
    plan: str = "student_pro"


class BulkInviteRequest(BaseModel):
    emails: list[str]
    role: str = "student"
    plan: str = "student_pro"


class AcceptInviteRequest(BaseModel):
    token: Optional[str] = None
    email: Optional[str] = None
    password: Optional[str] = "Student123!"
    name: Optional[str] = None

class RecordLoginRequest(BaseModel):
    email: str
    status: str = "success"  # "success" | "blocked"
    photo_url: Optional[str] = None
    avatar_base64: Optional[str] = None


# ---------------- Serializers ----------------
def _admin_dict(a: AdminUser) -> dict:
    return {
        "id": a.id, "email": a.email, "name": a.name, "role": a.role,
        "institution_id": a.institution_id,
        "last_login_at": a.last_login_at.isoformat() if a.last_login_at else None,
    }



def _invitation_dict(inv: Invitation) -> dict:
    return {
        "id": inv.id,
        "email": inv.email,
        "institution_id": inv.institution_id,
        "role": inv.role,
        "plan": inv.plan,
        "status": inv.status,
        "invited_by": inv.invited_by,
        "created_at": inv.created_at.isoformat() if inv.created_at else None,
        "expires_at": inv.expires_at.isoformat() if inv.expires_at else None,
        "accepted_at": inv.accepted_at.isoformat() if inv.accepted_at else None,
    }

def _student_dict(s: Student) -> dict:
    # Deliberately excludes any research content.
    return {
        "id": s.id, "email": s.email, "name": s.name, "role": s.role,
        "photo_url": s.photo_url,
        "avatar_base64": getattr(s, "avatar_base64", None) or s.photo_url,
        "status": s.status, "institution_id": s.institution_id,
        "ban_reason": s.ban_reason,
        "banned_at": s.banned_at.isoformat() if s.banned_at else None,
        "suspended_until": s.suspended_until.isoformat() if s.suspended_until else None,
        "created_at": s.created_at.isoformat() if s.created_at else None,
        "last_active_at": s.last_active_at.isoformat() if s.last_active_at else None,
    }


# ---------------- Auth ----------------
@router.post("/auth/login")
def login(req: LoginRequest, db: Session = Depends(get_db)):
    admin = db.query(AdminUser).filter(AdminUser.email == req.email.strip().lower()).first()
    if not admin or not auth.verify_password(req.password, admin.password_hash):
        raise HTTPException(401, "Invalid credentials")
    token = auth.create_session(db, admin)
    svc.log_action(db, admin.id, admin.institution_id, "login")
    return {"token": token, "admin": _admin_dict(admin)}


@router.post("/auth/logout")
def logout(admin: AdminUser = Depends(auth.current_admin),
           authorization: str = "",
           db: Session = Depends(get_db)):
    # We read the token from header again — simplest is to accept the header
    if authorization.lower().startswith("bearer "):
        tok = authorization.split(" ", 1)[1].strip()
        sess = db.query(AdminSession).filter(AdminSession.token == tok).first()
        if sess:
            db.delete(sess); db.commit()
    svc.log_action(db, admin.id, admin.institution_id, "logout")
    return {"ok": True}


@router.get("/me")
def me(admin: AdminUser = Depends(auth.current_admin)):
    return _admin_dict(admin)


# ---------------- Dashboard ----------------
@router.get("/dashboard/summary")
def dashboard(admin: AdminUser = Depends(auth.current_admin),
              db: Session = Depends(get_db)):
    return svc.dashboard_summary(db, admin.institution_id)


# ---------------- Institution ----------------
@router.get("/institution")
def get_institution(admin: AdminUser = Depends(auth.current_admin),
                    db: Session = Depends(get_db)):
    inst = db.query(Institution).filter(Institution.id == admin.institution_id).first()
    if not inst:
        raise HTTPException(404, "No institution")
    used = db.query(Student).filter(Student.institution_id == inst.id, Student.status != "banned").count()
    now = datetime.utcnow()
    pending = db.query(Invitation).filter(
        Invitation.institution_id == inst.id,
        Invitation.status == "pending",
        Invitation.expires_at > now,
    ).count()
    return {
        "id": inst.id, "name": inst.name, "plan": inst.plan,
        "license_limit": inst.license_limit,
        "used": used,
        "pending": pending,
        "available": max(0, inst.license_limit - (used + pending)),
        "subscription_status": inst.subscription_status,
        "renewal_date": inst.renewal_date.isoformat() if inst.renewal_date else None,
    }


# ---------------- Students ----------------
@router.get("/students")
def list_students(
    search: Optional[str] = None,
    status: Optional[str] = None,
    page: int = 1,
    page_size: int = 20,
    admin: AdminUser = Depends(auth.current_admin),
    db: Session = Depends(get_db),
):
    q = db.query(Student)
    if admin.institution_id:
        q = q.filter(Student.institution_id == admin.institution_id)
    if search:
        like = f"%{search.strip()}%"
        q = q.filter((Student.email.ilike(like)) | (Student.name.ilike(like)))
    if status:
        q = q.filter(Student.status == status)
    total = q.count()
    rows = (q.order_by(Student.created_at.desc())
              .offset((page - 1) * page_size)
              .limit(page_size).all())
    if User is not None:
        for s in rows:
            if not getattr(s, "avatar_base64", None) and s.email:
                try:
                    u = db.query(User).filter(User.email == s.email.strip().lower()).first()
                    if u and u.avatar_base64:
                        s.avatar_base64 = u.avatar_base64
                        db.commit()
                except Exception:
                    pass
    return {
        "total": total, "page": page, "page_size": page_size,
        "items": [_student_dict(s) for s in rows],
    }


@router.get("/students/{student_id}")
def get_student(student_id: int,
                admin: AdminUser = Depends(auth.current_admin),
                db: Session = Depends(get_db)):
    s = db.query(Student).filter(Student.id == student_id).first()
    if not s:
        raise HTTPException(404, "Student not found")
    if admin.institution_id and s.institution_id != admin.institution_id:
        raise HTTPException(403, "Not in your institution")
    usage = svc.student_usage_summary(db, s.id)
    return {"student": _student_dict(s), "usage": usage}


@router.patch("/students/{student_id}/status")
def change_status(student_id: int, req: StatusRequest,
                  admin: AdminUser = Depends(auth.current_admin),
                  db: Session = Depends(get_db)):
    s = db.query(Student).filter(Student.id == student_id).first()
    if not s:
        raise HTTPException(404, "Student not found")
    if admin.institution_id and s.institution_id != admin.institution_id:
        raise HTTPException(403, "Not in your institution")

    if req.status not in ("active", "suspended", "banned"):
        raise HTTPException(400, "Invalid status")

    action = req.status if req.status != "active" else "unban"
    if req.status == "banned":
        s.ban_reason = req.reason or "Policy violation"
        s.banned_by = admin.id
        s.banned_at = datetime.utcnow()
        s.suspended_until = None
    elif req.status == "suspended":
        s.ban_reason = req.reason or "Temporary suspension"
        s.suspended_until = (datetime.utcnow()
                             + timedelta(days=req.suspend_days or 7))
    else:  # active
        s.ban_reason = None
        s.banned_at = None
        s.banned_by = None
        s.suspended_until = None

    s.status = req.status
    db.commit()
    svc.log_action(db, admin.id, admin.institution_id, action,
                   target_student_id=s.id,
                   details=req.reason or "")
    return _student_dict(s)


@router.post("/students/{student_id}/reset-password")
def reset_password(student_id: int,
                   admin: AdminUser = Depends(auth.current_admin),
                   db: Session = Depends(get_db)):
    s = db.query(Student).filter(Student.id == student_id).first()
    if not s:
        raise HTTPException(404, "Student not found")
    if admin.institution_id and s.institution_id != admin.institution_id:
        raise HTTPException(403, "Not in your institution")
    # In production: send an email with a reset link.
    # For MVP: log the action and return success. No password is ever revealed.
    svc.log_action(db, admin.id, admin.institution_id, "reset_password",
                   target_student_id=s.id)
    return {
        "ok": True,
        "message": f"Password reset email queued for {s.email}",
        "email": s.email,
    }


# ---------------- Analytics ----------------
@router.get("/analytics/features")
def feature_adoption(admin: AdminUser = Depends(auth.current_admin),
                     db: Session = Depends(get_db)):
    return svc.feature_adoption(db, admin.institution_id)


@router.get("/analytics/monthly")
def monthly(admin: AdminUser = Depends(auth.current_admin),
            db: Session = Depends(get_db)):
    return {"months": svc.monthly_active(db, admin.institution_id)}


# ---------------- Audit ----------------
@router.get("/audit-logs")
def audit_logs(limit: int = 50,
               admin: AdminUser = Depends(auth.current_admin),
               db: Session = Depends(get_db)):
    q = db.query(svc.AuditLog)
    if admin.institution_id:
        q = q.filter(svc.AuditLog.institution_id == admin.institution_id)
    rows = q.order_by(svc.AuditLog.created_at.desc()).limit(limit).all()
    return [{
        "id": r.id,
        "action": r.action,
        "admin_id": r.admin_id,
        "target_student_id": r.target_student_id,
        "details": r.details,
        "created_at": r.created_at.isoformat() if r.created_at else None,
    } for r in rows]


# ---------------- Login Activity Tracking ----------------
@router.post("/logins/record")
def record_login(req: RecordLoginRequest, db: Session = Depends(get_db)):
    """Public endpoint: records login activity and updates student photo if provided."""
    email = req.email.strip().lower()
    student = db.query(Student).filter(Student.email == email).first()
    if not student:
        inst = db.query(Institution).first()
        student = Student(
            email=email,
            name=email.split("@")[0],
            institution_id=inst.id if inst else None,
            photo_url=req.photo_url,
            status="active",
        )
        db.add(student)
        db.commit()
        db.refresh(student)
    else:
        if req.photo_url:
            student.photo_url = req.photo_url
        if req.avatar_base64:
            student.avatar_base64 = req.avatar_base64
        student.last_active_at = datetime.utcnow()

    log_entry = StudentLoginLog(
        student_id=student.id,
        email=email,
        login_time=datetime.utcnow(),
        status=req.status,
    )
    db.add(log_entry)
    db.commit()
    db.refresh(log_entry)
    return {"ok": True, "id": log_entry.id}


@router.get("/logins/recent")
def recent_logins(limit: int = 50,
                  admin: AdminUser = Depends(auth.current_admin),
                  db: Session = Depends(get_db)):
    """Protected endpoint: STRICTLY filtered to students of the admin's institution."""
    if not admin.institution_id:
        return []

    # Get all students belonging to the admin's institution
    inst_students = db.query(Student).filter(Student.institution_id == admin.institution_id).all()
    inst_student_ids = {s.id for s in inst_students}
    inst_emails = {s.email.lower() for s in inst_students if s.email}
    students_by_id = {s.id: s for s in inst_students}
    students_by_email = {s.email.lower(): s for s in inst_students if s.email}

    if not inst_student_ids and not inst_emails:
        return []

    # Fetch login logs matching students in this institution
    logs = (
        db.query(StudentLoginLog)
        .filter(
            (StudentLoginLog.student_id.in_(inst_student_ids)) |
            (StudentLoginLog.email.in_(inst_emails))
        )
        .order_by(StudentLoginLog.login_time.desc())
        .limit(limit)
        .all()
    )

    results = []
    for log_item in logs:
        st = None
        if log_item.student_id and log_item.student_id in students_by_id:
            st = students_by_id[log_item.student_id]
        elif log_item.email and log_item.email.lower() in students_by_email:
            st = students_by_email[log_item.email.lower()]

        # Strictly skip any log whose student is not confirmed in this institution
        if not st or st.institution_id != admin.institution_id:
            continue

        avatar_b64 = getattr(st, "avatar_base64", None) if st else None
        if not avatar_b64 and log_item.email and User is not None:
            try:
                u = db.query(User).filter(User.email == log_item.email.strip().lower()).first()
                if u and u.avatar_base64:
                    avatar_b64 = u.avatar_base64
                    if st:
                        st.avatar_base64 = avatar_b64
                        db.commit()
            except Exception:
                pass

        results.append({
            "id": log_item.id,
            "student_name": st.name if (st and st.name) else (log_item.email.split("@")[0] if log_item.email else "Unknown"),
            "email": log_item.email,
            "role": st.role if (st and st.role) else "student",
            "photo_url": st.photo_url if st else None,
            "avatar_base64": avatar_b64 or (st.photo_url if st else None),
            "login_time": log_item.login_time.isoformat() if log_item.login_time else None,
            "status": log_item.status,
            "device": "Mobile App",
            "method": "Firebase Auth",
        })
    return results


# ---------------- Usage recording (called from the app, optional) --------
@router.post("/usage/record")
def record_usage(req: RecordUsageRequest, db: Session = Depends(get_db)):
    """Public endpoint — the mobile app can call this to log usage.
    No auth required (it's fire-and-forget), but only safe fields are accepted."""
    student = None
    if req.student_external_uid:
        student = db.query(Student).filter(
            Student.external_uid == req.student_external_uid).first()
    if not student and req.student_email:
        email = req.student_email.strip().lower()
        student = db.query(Student).filter(Student.email == email).first()
        if not student:
            inst = db.query(Institution).first()
            student = Student(
                email=email,
                name=email.split("@")[0],
                institution_id=inst.id if inst else None,
                status="active",
            )
            db.add(student)
            db.commit()
            db.refresh(student)

    ev = UsageEvent(
        student_id=student.id if student else None,
        institution_id=student.institution_id if student else None,
        event_type=req.event_type,
    )
    db.add(ev)
    if student:
        student.last_active_at = datetime.utcnow()
    db.commit()
    return {"ok": True}


# ---------------- Student self-registration (called from app) --------
@router.post("/students/register")
def register_student(req: RegisterStudentRequest, db: Session = Depends(get_db)):
    """App calls this when a new user signs up. Idempotent by email."""
    email = req.email.strip().lower()
    existing = db.query(Student).filter(Student.email == email).first()
    if existing:
        if req.external_uid and not existing.external_uid:
            existing.external_uid = req.external_uid
            db.commit()
        return {"id": existing.id, "created": False}

    # Attach to the default institution (single-tenant MVP)
    inst = db.query(Institution).first()
    s = Student(
        external_uid=req.external_uid,
        email=email,
        name=req.name or email.split("@")[0],
        institution_id=inst.id if inst else None,
    )
    db.add(s); db.commit(); db.refresh(s)
    return {"id": s.id, "created": True}

# ---------------- SaaS Invitation System ----------------
@router.post("/invitations")
def invite_student(
    req: InviteStudentRequest,
    admin: AdminUser = Depends(auth.current_admin),
    db: Session = Depends(get_db),
):
    inst = db.query(Institution).filter(Institution.id == admin.institution_id).first()
    if not inst:
        raise HTTPException(404, "Institution not found")

    email = req.email.strip().lower()
    if not email or "@" not in email:
        raise HTTPException(400, "Invalid email address")

    # Check license limit
    current_students = db.query(Student).filter(
        Student.institution_id == inst.id,
        Student.status != "banned",
    ).count()

    now = datetime.utcnow()
    pending_invites = db.query(Invitation).filter(
        Invitation.institution_id == inst.id,
        Invitation.status == "pending",
        Invitation.expires_at > now,
    ).count()

    if (current_students + pending_invites) >= inst.license_limit:
        raise HTTPException(400, "No available licenses.")

    # Check if student is already active in this institution
    existing_student = db.query(Student).filter(
        Student.email == email,
        Student.institution_id == inst.id,
    ).first()
    if existing_student and existing_student.status != "banned":
        raise HTTPException(400, "Student is already enrolled in your institution.")

    # Check if pending invite already exists
    existing_invite = db.query(Invitation).filter(
        Invitation.email == email,
        Invitation.institution_id == inst.id,
        Invitation.status == "pending",
        Invitation.expires_at > now,
    ).first()
    if existing_invite:
        raise HTTPException(
            400,
            "An active invitation is already pending for this email. You can resend it.",
        )

    invitation = Invitation(
        id=str(uuid.uuid4()),
        email=email,
        institution_id=inst.id,
        role=req.role,
        plan=req.plan,
        status="pending",
        invited_by=admin.id,
        created_at=now,
        expires_at=now + timedelta(days=7),
    )
    db.add(invitation)
    db.commit()
    db.refresh(invitation)

    svc.log_action(db, admin.id, inst.id, "invite_student", details=f"Invited {email}")

    # For MVP, print invite link to console
    invite_link = f"http://localhost:8001/api/admin/auth/accept-invite?token={invitation.id}"
    print(f"\n[INVITATION LINK GENERATED]\nTo: {email}\nLink: {invite_link}\nExpires: {invitation.expires_at}\n")

    return {
        "ok": True,
        "invitation": _invitation_dict(invitation),
        "invite_link": invite_link,
    }


@router.post("/invitations/bulk")
def bulk_invite(
    req: BulkInviteRequest,
    admin: AdminUser = Depends(auth.current_admin),
    db: Session = Depends(get_db),
):
    inst = db.query(Institution).filter(Institution.id == admin.institution_id).first()
    if not inst:
        raise HTTPException(404, "Institution not found")

    current_students = db.query(Student).filter(
        Student.institution_id == inst.id,
        Student.status != "banned",
    ).count()

    now = datetime.utcnow()
    pending_invites = db.query(Invitation).filter(
        Invitation.institution_id == inst.id,
        Invitation.status == "pending",
        Invitation.expires_at > now,
    ).count()

    available_licenses = max(0, inst.license_limit - (current_students + pending_invites))
    if available_licenses <= 0:
        raise HTTPException(400, "No available licenses.")

    sent = 0
    failed = 0
    results = []

    cleaned_emails = []
    seen = set()
    for raw in req.emails:
        e = raw.strip().lower()
        if e and "@" in e and e not in seen:
            seen.add(e)
            cleaned_emails.append(e)

    for email in cleaned_emails:
        if available_licenses <= 0:
            failed += 1
            results.append({"email": email, "status": "failed", "reason": "No licenses left"})
            continue

        existing_student = db.query(Student).filter(
            Student.email == email,
            Student.institution_id == inst.id,
        ).first()
        if existing_student and existing_student.status != "banned":
            failed += 1
            results.append({"email": email, "status": "failed", "reason": "Already enrolled"})
            continue

        existing_invite = db.query(Invitation).filter(
            Invitation.email == email,
            Invitation.institution_id == inst.id,
            Invitation.status == "pending",
            Invitation.expires_at > now,
        ).first()
        if existing_invite:
            failed += 1
            results.append({"email": email, "status": "failed", "reason": "Already pending"})
            continue

        invitation = Invitation(
            id=str(uuid.uuid4()),
            email=email,
            institution_id=inst.id,
            role=req.role,
            plan=req.plan,
            status="pending",
            invited_by=admin.id,
            created_at=now,
            expires_at=now + timedelta(days=7),
        )
        db.add(invitation)
        available_licenses -= 1
        sent += 1
        results.append({"email": email, "status": "sent", "id": invitation.id})

    db.commit()
    svc.log_action(db, admin.id, inst.id, "bulk_invite", details=f"Sent {sent}, Failed {failed}")
    return {"sent": sent, "failed": failed, "results": results}


@router.get("/invitations")
def list_invitations(
    status: Optional[str] = None,
    admin: AdminUser = Depends(auth.current_admin),
    db: Session = Depends(get_db),
):
    q = db.query(Invitation).filter(Invitation.institution_id == admin.institution_id)
    if status:
        q = q.filter(Invitation.status == status)
    invites = q.order_by(Invitation.created_at.desc()).all()
    now = datetime.utcnow()
    for inv in invites:
        if inv.status == "pending" and inv.expires_at < now:
            inv.status = "expired"
    db.commit()
    return [_invitation_dict(inv) for inv in invites]


@router.post("/invitations/{invite_id}/resend")
def resend_invitation(
    invite_id: str,
    admin: AdminUser = Depends(auth.current_admin),
    db: Session = Depends(get_db),
):
    inv = db.query(Invitation).filter(
        Invitation.id == invite_id,
        Invitation.institution_id == admin.institution_id,
    ).first()
    if not inv:
        raise HTTPException(404, "Invitation not found")

    now = datetime.utcnow()
    inv.status = "pending"
    inv.expires_at = now + timedelta(days=7)
    db.commit()

    svc.log_action(db, admin.id, admin.institution_id, "resend_invite", details=f"Resent to {inv.email}")
    link = f"http://localhost:8001/api/admin/auth/accept-invite?token={inv.id}"
    print(f"\n[INVITATION RESENT]\nTo: {inv.email}\nLink: {link}\n")
    return {"ok": True, "invitation": _invitation_dict(inv), "invite_link": link}


@router.post("/invitations/{invite_id}/revoke")
def revoke_invitation(
    invite_id: str,
    admin: AdminUser = Depends(auth.current_admin),
    db: Session = Depends(get_db),
):
    inv = db.query(Invitation).filter(
        Invitation.id == invite_id,
        Invitation.institution_id == admin.institution_id,
    ).first()
    if not inv:
        raise HTTPException(404, "Invitation not found")

    inv.status = "revoked"
    db.commit()
    svc.log_action(db, admin.id, admin.institution_id, "revoke_invite", details=f"Revoked for {inv.email}")
    return {"ok": True, "invitation": _invitation_dict(inv)}


@router.post("/auth/accept-invite")
def accept_invite(req: AcceptInviteRequest, db: Session = Depends(get_db)):
    """Public endpoint: Student accepts campus invite, links account to institution."""
    inv = None
    if req.token:
        inv = db.query(Invitation).filter(Invitation.id == req.token.strip()).first()
    elif req.email:
        inv = (
            db.query(Invitation)
            .filter(
                Invitation.email == req.email.strip().lower(),
                Invitation.status == "pending",
            )
            .order_by(Invitation.created_at.desc())
            .first()
        )

    if not inv:
        raise HTTPException(404, "Invitation not found.")

    now = datetime.utcnow()
    if inv.status != "pending":
        raise HTTPException(400, f"Invitation cannot be accepted because it is {inv.status}.")
    if inv.expires_at < now:
        inv.status = "expired"
        db.commit()
        raise HTTPException(400, "Invitation has expired.")

    email = inv.email.strip().lower()
    student = db.query(Student).filter(Student.email == email).first()
    pwd_hash = auth.hash_password(req.password or "Student123!")

    if student:
        student.institution_id = inv.institution_id
        student.status = "active"
        student.role = inv.role
        student.password_hash = pwd_hash
        if req.name and req.name.strip():
            student.name = req.name.strip()
        student.last_active_at = now
    else:
        student = Student(
            email=email,
            name=req.name.strip() if req.name else email.split("@")[0],
            institution_id=inv.institution_id,
            role=inv.role,
            status="active",
            password_hash=pwd_hash,
            created_at=now,
            last_active_at=now,
        )
        db.add(student)
        db.flush()

    inv.status = "accepted"
    inv.accepted_at = now

    login_log = StudentLoginLog(
        student_id=student.id,
        email=student.email,
        login_time=now,
        status="success",
    )
    db.add(login_log)
    db.commit()
    db.refresh(student)

    return {
        "ok": True,
        "message": "Invitation accepted successfully",
        "student": _student_dict(student),
    }
