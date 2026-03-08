import firebase_admin
from firebase_admin import auth, credentials
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from passlib.context import CryptContext
from config import CONFIG
import logging

LOGGER = logging.getLogger(__name__)

firebase_creds = CONFIG.FIREBASE_CONFIG
security = HTTPBearer()

try:
    # Initialize Firebase with the credentials from the environment variable
    cred = credentials.Certificate(firebase_creds)
    firebase_admin.initialize_app(cred)
    LOGGER.info("Firebase initialized successfully from environment variable.")
except Exception as e:
    LOGGER.error(f"Error initializing Firebase from environment variable")


pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")

def hash_password(password: str) -> str:
    # Argon2id supports long passwords, no need to truncate
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

async def get_current_user(res: HTTPAuthorizationCredentials = Depends(security)):
    token = res.credentials
    try:
        decoded_token = auth.verify_id_token(token)
        return decoded_token.get("uid")
    except Exception as e:
        LOGGER.error(f"Error occurred while verifying ID token")
        raise HTTPException(status_code=401, detail="Invalid Authentication")