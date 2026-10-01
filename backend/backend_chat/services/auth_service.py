import firebase_admin
from firebase_admin import credentials, auth
from fastapi import HTTPException, Header

# Initialize Firebase Admin once at startup
if not firebase_admin._apps:
    cred = credentials.Certificate("firebase-service-account.json")
    firebase_admin.initialize_app(cred)

async def verify_token(authorization: str = Header(...)) -> str:
    """Verify the Firebase ID token and return the user's UID."""
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization header")
    
    id_token = authorization.split("Bearer ")[1]
    try:
        decoded_token = auth.verify_id_token(id_token)
        return decoded_token["uid"]
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired token")