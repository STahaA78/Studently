from pydantic import BaseModel, Field
from datetime import datetime
from typing import List, Optional

class Comment(BaseModel):
    user_id: str
    username: str # Still needed for storage/display
    content: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)

class PostCreate(BaseModel):
    author_id: str
    content: str
    media_urls: List[str] = []

class PostOut(BaseModel):
    id: str = Field(alias="_id")
    author_id: str
    author_name: str
    author_pic: Optional[str] = None
    content: str
    media_urls: List[str] = []
    likes: List[str] = []
    comments: List[Comment] = []
    timestamp: datetime

    class Config:
        populate_by_name = True

class CommentCreate(BaseModel):
    user_id: str
    # username field removed; will be fetched from DB
    content: str