from pydantic import BaseModel, Field
from datetime import datetime
from typing import List, Optional

class MessageCreate(BaseModel):
    sender_id: str
    receiver_id: str
    text: str
    attachments: List[str] = []

class MessageOut(BaseModel):
    id: str = Field(alias="_id")
    conversation_id: str
    sender_id: str
    receiver_id: str
    text: str
    attachments: List[str] = []
    timestamp: datetime
    status: str = "sent"
    is_deleted: bool = False

    class Config:
        populate_by_name = True

class ConversationOut(BaseModel):
    id: str = Field(alias="_id")
    participants: List[str]
    last_message: Optional[dict] = None
    unread_counts: dict = {}
    created_at: datetime

    class Config:
        populate_by_name = True