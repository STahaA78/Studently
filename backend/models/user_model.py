from pydantic import BaseModel, EmailStr, field_validator
from datetime import date, datetime
from typing import Optional, List

class UserCreate(BaseModel):
    Name: str
    email: EmailStr
    password: str
    birthday: date  
    department: str
    batch: str
    interests: List[str] = []
    university: str = "FAST"
    profile_picture: Optional[str] = None
    bio: Optional[str] = None

    @field_validator("birthday", mode="before")
    def validate_birthday(cls, v):
        if isinstance(v, date):
            return v
        for fmt in ("%m/%d/%y", "%m/%d/%Y", "%Y-%m-%d"):
            try:
                return datetime.strptime(v, fmt).date()
            except ValueError:
                continue
        raise ValueError("Birthday must be in MM/DD/YY or MM/DD/YYYY format")

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserUpdate(BaseModel):
    Name: Optional[str] = None
    department: Optional[str] = None
    batch: Optional[str] = None
    interests: Optional[List[str]] = None
    profile_picture: Optional[str] = None
    bio: Optional[str] = None

class UserOut(BaseModel):
    id: str
    Name: str
    email: EmailStr
    birthday: date
    department: str
    batch: str
    interests: List[str] = []
    university: str
    profile_picture: Optional[str] = None
    bio: Optional[str] = None
    friends: List[str] = []
    created_at: Optional[datetime] = None

# Model for handling Accept/Reject actions
class FriendRequestAction(BaseModel):
    requester_id: str
    action: str  # Must be "accept" or "reject"

# NEW: Model for removing a friend
class FriendRemoveAction(BaseModel):
    friend_id: str