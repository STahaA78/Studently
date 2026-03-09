from fastapi import APIRouter, HTTPException, Depends
from datetime import datetime
from utils.auth import hash_password
from database import users_collection
from models.user_model import *
from utils.auth import verify_password
from utils.auth import get_current_user
import logging
import uuid
from datetime import datetime, timezone

router = APIRouter()
LOGGER = logging.getLogger(__name__)
# 3. Define your custom format (expects a 'uid' variable)
formatter = logging.Formatter(
    fmt="%(asctime)s | %(levelname)-8s | UID: [%(uid)s] | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
if not LOGGER.handlers:
    import sys
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(formatter)
    LOGGER.addHandler(handler)
    LOGGER.setLevel(logging.DEBUG)

# Helper to check if user is admin
def is_admin(user_id: str) -> bool:
    user = users_collection.find_one({"_id": user_id})
    if not user:
        return False
    # Check isAdmin field, default to False if missing
    return user.get("isAdmin", False)

#Create User
@router.post("/register")
def register(user: UserCreate):
    LOGGER.info("User Registration Started", extra={"uid": user.uid if user.uid else "Guest"})
    # Check if email is already taken
    if users_collection.find_one({"email": user.email.lower()}):
        raise HTTPException(status_code=400, detail="Email already registered")
    hashed_pass = hash_password(user.password)
    user_dict = user.model_dump()
    # Change: Use the provided uid or generate a new one if empty
    # We map this to '_id' so MongoDB uses it as the primary key
    user_id = user.uid if user.uid else str(uuid.uuid4())
    user_dict["_id"] = user_id
    user_dict["created_at"] = datetime.now(timezone.utc).replace(tzinfo=None)
    user_dict["password"] = hashed_pass
    user_dict["email"] = user.email.lower()
    user_dict["birthday"] = datetime.combine(user.birthday, datetime.min.time())
    user_dict["connection_count"] = 0
    # Remove the redundant uid field since it's now stored as _id
    if "uid" in user_dict:
        del user_dict["uid"]
    result = users_collection.insert_one(user_dict)
    LOGGER.info(f"User Registered Ended Successfully - id: {result.inserted_id}", extra={"uid": user_id})
    return {"success": True, "uid": str(result.inserted_id)}
#Verify User
@router.post("/login")
def login(user: UserLogin):
    LOGGER.info("User Login Started", extra={"uid": "Guest"})
    db_user = users_collection.find_one({"email": user.email.lower()})
    if not db_user:
        return {"success": False, "detail": "Invalid email or password"}
    if not verify_password(user.password, db_user["password"]):
        return {"success": False, "detail": "Invalid email or password"}
    LOGGER.info(f"User Login Ended Successfully - id: {db_user['_id']}", extra={"uid": str(db_user["_id"])})
    # Return the uid (_id) so the frontend can track the session locally
    return {"success": True, "uid": str(db_user["_id"])}

@router.get("/{user_id}/profile", response_model=UserProfileData)
def get_user_info(user_id: str, user: str = Depends(get_current_user)):
    LOGGER.info(f"Fetching profile for user ID: {user}", extra={"uid": user})
        
    if user_id != "0":
        if is_admin(user):
            LOGGER.info(f"Admin accessing  profile of user ID: {user_id}", extra={"uid": user})
        else:
            LOGGER.warning(f"Unauthorized access attempt to user ID: {user_id} by user ID: {user}", extra={"uid": user})
            raise HTTPException(status_code=403, detail="Not authorized to access this profile")
    else:
        LOGGER.info(f"User accessing own profile", extra={"uid": user})
        user_id = user  # Override to fetch own profile when user_id is "0"

    user_data = users_collection.find_one(
        {
            "_id": user_id
        },
        {

            "name": 1,
            "email": 1,
            "connection_count"
            "interests": 1,
            "department": 1,
            "batch": 1,
        }
    )
    LOGGER.debug(f"Database query result for user ID {user_id}: {user_data}", extra={"uid": user})
    if not user_data:
        LOGGER.warning(f"User not found in DB for ID: {user_id}", extra={"uid": user_id})
        raise HTTPException(status_code=404, detail="User not found")
    user_data["id"] = user_id # Insert id
    LOGGER.info(f"Profile fetched successfully for user ID: {user_id}", extra={"uid": user})
    return user_data