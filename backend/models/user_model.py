from pydantic import BaseModel, EmailStr, field_validator,Field
from datetime import date, datetime
from typing import Optional, List, Literal
from models.config import Interest
class UserCreate(BaseModel):
    uid: str = ""  # New: Field for custom or generated UID
    name: str
    email: EmailStr
    birthday: date  
    department: str
    batch: str
    interests: List[Interest] = []
    university: str = "FAST"
    profilePhotoUrl: Optional[str] = None
    bio: Optional[str] = None
    isAdmin: bool = False

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

class UserOut(BaseModel):
    id: str = Field(alias="_id")  # This maps to the internal MongoDB _id (which is now our uid)
    name: str
    email: EmailStr
    department: str
    batch: str
    interests: List[Interest] = []
    profilePhotoUrl: Optional[str] = None
    bio: Optional[str] = None
    friends: List[str] = []
    created_at: Optional[datetime] = None
    isAdmin: bool = False
    class Config:
        allow_population_by_field_name = True

class FriendRequestAction(BaseModel):
    requester_id: str
    action: str

class FriendRemoveAction(BaseModel):
    friend_id: str

class UserProfileData(BaseModel):
    id: str
    name: str
    email: EmailStr
    interests: List[Interest]
    department: str
    batch: str
    profilePhotoUrl: Optional[str] = None
    friendsCount: int

class EditProfileData(BaseModel):
    name: Optional[str] = None
    department: Optional[str] = None
    batch: Optional[str] = None
    interests: Optional[List[Interest]] = None

class FriendStatus(BaseModel):
    id: str
    status: Literal["friends","incoming_request","none","error"]

class ConnectionStatusRequest(BaseModel):
    target_ids: List[str]
