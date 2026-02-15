from fastapi import APIRouter, HTTPException, Depends # Added Depends
from database import conversations_collection, messages_collection
from models.chat_model import MessageCreate, MessageOut, ConversationOut
from bson import ObjectId
from datetime import datetime
from pydantic import BaseModel
from utils.auth import get_current_user # Import your Security Guard
import logging
from utils.websocket_manager import manager
router = APIRouter()
LOGGER = logging.getLogger(__name__)

# --- MODEL UPDATE ---
# We no longer need MarkReadRequest because user_id comes from the Token!
# --------------------

def fix_id(doc):
    doc["_id"] = str(doc["_id"])
    return doc

# 1. GET CONVERSATIONS (Already updated)
@router.get("/conversations", response_model=list[ConversationOut])
def get_conversations(current_user_id: str = Depends(get_current_user)):
    LOGGER.debug(f"Fetching conversations for verified user: {current_user_id}")
    try:
        conversations = list(
            conversations_collection.find({"participants": current_user_id})
            .sort("last_message.timestamp", -1)
        )
        return [fix_id(conv) for conv in conversations]
    except Exception as e:
        LOGGER.error(f"Error fetching conversations: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

# 2. GET MESSAGES (Added JWT Check)
@router.get("/{conversation_id}/messages", response_model=list[MessageOut])
def get_messages(conversation_id: str, current_user_id: str = Depends(get_current_user)):
    if not ObjectId.is_valid(conversation_id):
        raise HTTPException(status_code=400, detail="Invalid ID")
    
    # Optional Security: Verify the current_user is actually a participant in this chat
    conv = conversations_collection.find_one({"_id": ObjectId(conversation_id), "participants": current_user_id})
    if not conv:
        raise HTTPException(status_code=403, detail="Not authorized to view this conversation")

    try:
        messages = list(messages_collection.find({"conversation_id": conversation_id}).sort("timestamp", 1))
        return [fix_id(msg) for msg in messages]
    except Exception as e:
        LOGGER.error(f"Error fetching messages: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

# 3. SEND MESSAGE (Sender ID comes from Token)
@router.post("/send", response_model=dict)
async def send_message(msg: MessageCreate, current_user_id: str = Depends(get_current_user)):
    try:
        # 1. Validate Conversation and get participants
        if not ObjectId.is_valid(msg.conversation_id):
            raise HTTPException(status_code=400, detail="Invalid conversation ID")
            
        conv = conversations_collection.find_one({"_id": ObjectId(msg.conversation_id)})
        if not conv:
            raise HTTPException(status_code=404, detail="Conversation not found")
        
        # Security: Ensure sender is a participant
        if current_user_id not in conv["participants"]:
            raise HTTPException(status_code=403, detail="Not a member of this chat")

        # 2. Save Message
        message_dict = msg.model_dump()
        message_dict.update({
            "sender_id": current_user_id,
            "timestamp": datetime.utcnow(),
            "status": "sent",
            "is_deleted": False
        })
        messages_collection.insert_one(message_dict)

        # 3. Update Conversation Meta & Unread Counts for all OTHER participants
        other_participants = [p for p in conv["participants"] if p != current_user_id]
        
        update_query = {
            "$set": {
                "last_message": {
                    "text": msg.text,
                    "sender_id": current_user_id,
                    "timestamp": message_dict["timestamp"]
                }
            }
        }
        
        # Increment unread counts for everyone else in the group/chat
        for p_id in other_participants:
            update_query.setdefault("$inc", {})[f"unread_counts.{p_id}"] = 1

        conversations_collection.update_one({"_id": ObjectId(msg.conversation_id)}, update_query)

        # 4. REAL-TIME: Broadcast to ALL participants
        ws_payload = {
            "type": "NEW_MESSAGE",
            "data": {
                "conversation_id": msg.conversation_id,
                "sender_id": current_user_id,
                "text": msg.text,
                "timestamp": message_dict["timestamp"].isoformat()
            }
        }

        for p_id in conv["participants"]:
            await manager.send_to_user(ws_payload, p_id)

        return {"success": True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 4. MARK AS READ (User ID comes from Token)
@router.post("/{conversation_id}/read")
def mark_conversation_as_read(conversation_id: str, current_user_id: str = Depends(get_current_user)):
    if not ObjectId.is_valid(conversation_id):
        raise HTTPException(status_code=400, detail="Invalid ID")
        
    try:
        # SECURE: req.user_id is replaced by current_user_id from Token
        conversations_collection.update_one(
            {"_id": ObjectId(conversation_id)},
            {"$set": {f"unread_counts.{current_user_id}": 0}}
        )

        messages_collection.update_many(
            {
                "conversation_id": conversation_id,
                "sender_id": {"$ne": current_user_id}, 
                "status": {"$ne": "read"}
            },
            {"$set": {"status": "read"}}
        )

        return {"success": True, "message": "Marked as read"}
    except Exception as e:
        LOGGER.error(f"Error marking read: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")
@router.post("/{receiver_id}/create_chat")
def create_chat(receiver_id: str, current_user_id: str = Depends(get_current_user)):
    try:
        participants = sorted([current_user_id, receiver_id])
        
        conversation = conversations_collection.find_one({
            "participants": {"$all": participants, "$size": 2}
        })
        
        if conversation:
            return {"success": True, "conversation_id": str(conversation["_id"])}
        
        new_conv = {
            "participants": participants,
            "created_at": datetime.utcnow(),
            "unread_counts": {p: 0 for p in participants},
            "last_message": None
        }
        res = conversations_collection.insert_one(new_conv)
        return {"success": True, "conversation_id": str(res.inserted_id)}
    except Exception as e:
        LOGGER.error(f"Error creating chat: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")