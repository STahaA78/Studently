import firebase_admin
from firebase_admin import auth, credentials
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import os
from passlib.context import CryptContext
import json

# Get the JSON string from the environment variable
firebase_creds_json = os.environ.get("FIREBASE_CONFIG")
security = HTTPBearer()

if firebase_creds_json:
    try:
        # Parse the JSON string into a dictionary
        firebase_creds_dict = json.loads(firebase_creds_json)
        # Initialize Firebase with the credentials from the environment variable
        cred = credentials.Certificate(firebase_creds_dict)
        firebase_admin.initialize_app(cred)
        print("Firebase initialized successfully from environment variable.")
    except Exception as e:
        print(f"Error initializing Firebase from environment variable: {e}")
else:
    raise Exception("FIREBASE_CONFIG environment variable not set. Please set it with your Firebase service account JSON.")
    

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
        raise HTTPException(status_code=401, detail="Invalid Authentication")