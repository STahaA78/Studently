from fastapi import APIRouter, HTTPException, Depends
from datetime import datetime
from utils.auth import hash_password
from database import users_collection
from models.user_model import UserCreate, UserLogin
from utils.auth import verify_password
from bson import ObjectId
from utils.auth import get_current_user
import logging
import uuid
router = APIRouter()
LOGGER = logging.getLogger(__name__)
LOGGER.setLevel(logging.DEBUG)

#Create User
@router.post("/register")
def register(user: UserCreate):
    LOGGER.info("User Registration Started")
    # Check if email is already taken
    if users_collection.find_one({"email": user.email.lower()}):
        raise HTTPException(status_code=400, detail="Email already registered")
    hashed_pass = hash_password(user.password)
    user_dict = user.model_dump()
    # Change: Use the provided uid or generate a new one if empty
    # We map this to '_id' so MongoDB uses it as the primary key
    user_id = user.uid if user.uid else str(uuid.uuid4())
    user_dict["_id"] = user_id
    user_dict["password"] = hashed_pass
    user_dict["email"] = user.email.lower()
    user_dict["birthday"] = datetime.combine(user.birthday, datetime.min.time())
    # Remove the redundant uid field since it's now stored as _id
    if "uid" in user_dict:
        del user_dict["uid"]
    result = users_collection.insert_one(user_dict)
    LOGGER.info(f"User Registered Ended Successfully - id: {result.inserted_id}")
    return {"success": True, "uid": str(result.inserted_id)}
#Verify User
@router.post("/login")
def login(user: UserLogin):
    LOGGER.info("User Login Started")
    db_user = users_collection.find_one({"email": user.email.lower()})
    if not db_user:
        return {"success": False, "detail": "Invalid email or password"}
    if not verify_password(user.password, db_user["password"]):
        return {"success": False, "detail": "Invalid email or password"}
    LOGGER.info(f"User Login Ended Successfully - id: {db_user['_id']}")
    # Return the uid (_id) so the frontend can track the session locally
    return {"success": True, "uid": str(db_user["_id"])}

@router.get("/{user_id}/info")
def get_user_info(user_id: str, current_user: str = Depends(get_current_user)):
    try:
        query_id = ObjectId(user_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid User ID format")
    user = users_collection.find_one({"_id": query_id}, {"full_name": 1, "Name": 1, "email": 1})
    
    if not user:
        LOGGER.warning(f"User not found in DB for ID: {user_id}")
        return {"full_name": "Student User"}
    return {
        "full_name": user.get("Name") ,
        "email": user.get("email")
    }
@router.get("/health")
async def health_check():
    return {"status": "healthy"}
