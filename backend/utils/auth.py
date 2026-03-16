import firebase_admin
from firebase_admin import auth, credentials
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from passlib.context import CryptContext
from config import CONFIG
import logging

LOGGER = logging.getLogger(__name__)

# =========================
# Firebase Initialization
# =========================

firebase_creds = CONFIG.FIREBASE_CONFIG
security = HTTPBearer()

try:
    cred = credentials.Certificate(firebase_creds)

    # Prevent multiple Firebase initializations
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)

    LOGGER.info("Firebase initialized successfully.")

except Exception as e:
    LOGGER.error(f"Firebase initialization failed: {e}")
    raise


# =========================
# Password Hashing
# =========================

pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


# =========================
# JWT Authentication
# =========================

security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Verifies Firebase JWT token and returns UID
    """

    token = credentials.credentials

    try:
        decoded_token = auth.verify_id_token(token)

        uid = decoded_token.get("uid")

        if not uid:
            raise HTTPException(status_code=401, detail="Invalid token")

        return uid

    except Exception as e:
        LOGGER.error(f"Auth verification failed: {e}")
        raise HTTPException(status_code=401, detail="Invalid Authentication")