from fastapi import APIRouter, HTTPException
from datetime import datetime
from utils.auth import hash_password
from database import users_collection
from models.user_model import UserCreate, UserLogin
from utils.auth import verify_password
import logging
router = APIRouter()
LOGGER = logging.getLogger(__name__)
LOGGER.setLevel(logging.DEBUG)

#Create User
@router.post("/register")
def register(user: UserCreate):
    LOGGER.info("User Registration Started")
    LOGGER.debug("User Data: %s", user.model_dump())
    if users_collection.find_one({"email": user.email.lower()}):
        raise HTTPException(status_code=400, detail="Email already registered")
    hashed_pass = hash_password(user.password)
    user_dict = user.model_dump()
    user_dict["password"] = hashed_pass
    user_dict["email"] = user.email.lower()
    user_dict["birthday"] = datetime.combine(user.birthday, datetime.min.time())
    result = users_collection.insert_one(user_dict)
    LOGGER.info(f"User Registered Ended Successfully - id: {result.inserted_id}")
    return {"success": True}
#Verify User
@router.post("/login")
def login(user: UserLogin):
    LOGGER.info("User Login Started")
    LOGGER.debug("User Data: %s", user.model_dump())
    db_user = users_collection.find_one({"email": user.email.lower()})
    if not db_user:
        LOGGER.info("User Login Failed - Email not found")
        return {"success": False, "detail": "Invalid email or password"}
    if not verify_password(user.password, db_user["password"]):
        LOGGER.info("User Login Failed - Incorrect password")
        return {"success": False, "detail": "Invalid email or password"}
    LOGGER.info(f"User Login Ended Successfully - id: {db_user['_id']}")
    return {"success": True}
@router.get("/health")
async def health_check():
    return {"status": "healthy"}
