from database import SessionLocal, init_db
from schemas import UserCreate
from services import user_service

init_db()
db = SessionLocal()

username = "admin"
password = "admin123"   # change after first login

if user_service.get_by_username(db, username):
    print(f"User '{username}' already exists.")
else:
    user = user_service.create_user(db, UserCreate(
        username=username,
        email="admin@orbirag.local",
        password=password,
        role="admin",
    ))
    print(f"Created admin: {user.username} / {password}")

db.close()