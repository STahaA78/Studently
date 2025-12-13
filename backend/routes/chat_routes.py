from fastapi import APIRouter, HTTPException
from database import conversations_collection, messages_collection
from models.chat_model import MessageCreate, MessageOut, ConversationOut
from bson import ObjectId
from datetime import datetime
import logging

router = APIRouter()
LOGGER = logging.getLogger(__name__)
LOGGER.setLevel(logging.DEBUG)

def fix_id(doc):
    doc["_id"] = str(doc["_id"])
    return doc

@router.get("/user/{user_id}", response_model=list[ConversationOut])
def get_conversations(user_id: str):
    LOGGER.debug(f"Fetching conversations for user: {user_id}")
    try:
        conversations = list(conversations_collection.find({"participants": user_id}).sort("last_message.timestamp", -1))
        return [fix_id(conv) for conv in conversations]
    except Exception as e:
        LOGGER.error(f"Error fetching conversations: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

@router.get("/{conversation_id}/messages", response_model=list[MessageOut])
def get_messages(conversation_id: str):
    if not ObjectId.is_valid(conversation_id):
        raise HTTPException(status_code=400, detail="Invalid ID")
    
    try:
        messages = list(messages_collection.find({"conversation_id": conversation_id}).sort("timestamp", 1))
        return [fix_id(msg) for msg in messages]
    except Exception as e:
        LOGGER.error(f"Error fetching messages: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

@router.post("/send", response_model=dict)
def send_message(msg: MessageCreate):
    try:
        participants = sorted([msg.sender_id, msg.receiver_id])
        
        conversation = conversations_collection.find_one({
            "participants": {"$all": participants, "$size": 2}
        })
        
        conversation_id = None
        
        if not conversation:
            LOGGER.info(f"Creating new conversation: {participants}")
            new_conv = {
                "participants": participants,
                "created_at": datetime.utcnow(),
                "unread_counts": {p: 0 for p in participants},
                "last_message": None
            }
            res = conversations_collection.insert_one(new_conv)
            conversation_id = str(res.inserted_id)
        else:
            conversation_id = str(conversation["_id"])
        
        message_dict = msg.model_dump()
        message_dict["conversation_id"] = conversation_id
        message_dict["timestamp"] = datetime.utcnow()
        message_dict["status"] = "sent"
        message_dict["is_deleted"] = False
        
        messages_collection.insert_one(message_dict)
        
        conversations_collection.update_one(
            {"_id": ObjectId(conversation_id)},
            {
                "$set": {
                    "last_message": {
                        "text": msg.text,
                        "sender_id": msg.sender_id,
                        "timestamp": message_dict["timestamp"]
                    }
                },
                "$inc": {f"unread_counts.{msg.receiver_id}": 1}
            }
        )
        
        LOGGER.info(f"Message sent in conversation {conversation_id}")
        return {"success": True, "conversation_id": conversation_id}
    except Exception as e:
        LOGGER.error(f"Error sending message: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")