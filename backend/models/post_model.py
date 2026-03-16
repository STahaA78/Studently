from pydantic import BaseModel, Field
from datetime import datetime
from typing import List, Optional

class Comment(BaseModel):
    user_id: str
    username: str # Still needed for storage/display
    content: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)

class PostCreate(BaseModel):
    content: str
    media_urls: List[str] = []

class PostUpdate(BaseModel):
    content: str

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
    content: str