import firebase_admin
from firebase_admin import auth, credentials
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import os
from passlib.context import CryptContext
pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")

def hash_password(password: str) -> str:
    # Argon2id supports long passwords, no need to truncate
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)
security = HTTPBearer()
if not firebase_admin._apps:
    try:
        cred = credentials.Certificate("serviceAccountKey.json")
        firebase_admin.initialize_app(cred)
    except Exception as e:
        print(f"Error initializing Firebase: {e}")
async def get_current_user(res: HTTPAuthorizationCredentials = Depends(security)):
    token = res.credentials
    try:
        decoded_token = auth.verify_id_token(token)
        uid = decoded_token.get("uid")
        return uid
    except Exception as e:
        raise HTTPException(status_code=401, detail="Invalid Authentication")