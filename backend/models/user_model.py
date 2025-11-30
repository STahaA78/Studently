from pydantic import BaseModel, EmailStr, validator
from datetime import date, datetime
from typing import Optional, List

class UserCreate(BaseModel):
    Name: str
    email: EmailStr
    password: str
    birthday: str  # Input from frontend as MM/DD/YY
    department: str
    batch: str
    interests: List[str]
    university: str = "FAST"
    profile_picture: Optional[str] = None
    bio: Optional[str] = None

    @validator("birthday")
    def validate_birthday(cls, v):
        for fmt in ("%m/%d/%y", "%m/%d/%Y"):
            try:
                return datetime.strptime(v, fmt).date()
            except ValueError:
                continue
        raise ValueError("Birthday must be in MM/DD/YY or MM/DD/YYYY format")


class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserOut(BaseModel):
    id: str
    Name: str
    email: EmailStr
    birthday: date  # Output as date
    department: str
    batch: str
    interests: List[str]
    university: str
    profile_picture: Optional[str] = None
    bio: Optional[str] = None
    created_at: datetime
