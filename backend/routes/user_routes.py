from fastapi import APIRouter, HTTPException
from datetime import datetime
from utils.auth import hash_password
from database import users_collection
from models.user_model import UserCreate, UserOut, UserLogin
from utils.auth import verify_password

router = APIRouter()
#Create User
@router.post("/register")
def register(user: UserCreate):
    if users_collection.find_one({"email": user.email.lower()}):
        raise HTTPException(status_code=400, detail="Email already registered")
    hashed_pass = hash_password(user.password)
    user_dict = user.dict()
    user_dict["password"] = hashed_pass
    user_dict["email"] = user.email.lower()
    user_dict["birthday"] = datetime.combine(user.birthday, datetime.min.time())
    user_dict["created_at"] = datetime.utcnow()
    result = users_collection.insert_one(user_dict)
    return {"success": True}
#Verify User
@router.post("/login")
def login(user: UserLogin):
    db_user = users_collection.find_one({"email": user.email.lower()})
    if not db_user:
        return {"success": False, "detail": "Invalid email or password"}
    if not verify_password(user.password, db_user["password"]):
        return {"success": False, "detail": "Invalid email or password"}
    return {"success": True}
@router.get("/health")
async def health_check():
    return {"status": "healthy"}
