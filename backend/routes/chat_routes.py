from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, Request
from database import conversations_collection, messages_collection, users_collection, courses_collection
from models.chat_model import MessageCreate, MessageOut, ConversationOut
from bson import ObjectId
from datetime import datetime
from utils.auth import get_current_user
import logging
from utils.websocket_manager import manager
import os
import uuid
import shutil
router = APIRouter()
LOGGER = logging.getLogger(__name__)
UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)
def fix_id(doc):
    doc["_id"] = str(doc["_id"])
    return doc

@router.get("/conversations", response_model=list[ConversationOut])
def get_conversations(current_user_id: str = Depends(get_current_user)):
    try:
        conversations = list(
            conversations_collection.find({"participants": current_user_id})
            .sort("last_message.timestamp", -1)
        )
        return [fix_id(conv) for conv in conversations]
    except Exception as e:
        LOGGER.error(f"Error fetching conversations: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

@router.get("/{conversation_id}/messages", response_model=list[MessageOut])
def get_messages(conversation_id: str, current_user_id: str = Depends(get_current_user)):
    if not ObjectId.is_valid(conversation_id):
        raise HTTPException(status_code=400, detail="Invalid ID")
    
    conv = conversations_collection.find_one({"_id": ObjectId(conversation_id), "participants": current_user_id})
    if not conv:
        raise HTTPException(status_code=403, detail="Not authorized")

    try:
        messages = list(messages_collection.find({"conversation_id": conversation_id}).sort("timestamp", 1))
        return [fix_id(msg) for msg in messages]
    except Exception as e:
        LOGGER.error(f"Error fetching messages: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

@router.post("/send", response_model=dict)
async def send_message(msg: MessageCreate, current_user_id: str = Depends(get_current_user)):
    try:
        # 1. Fetch sender's name
        user = users_collection.find_one({"_id": current_user_id})
        sender_name = user.get("name", "Unknown") if user else "Unknown"

        if not ObjectId.is_valid(msg.conversation_id):
            raise HTTPException(status_code=400, detail="Invalid ID")
            
        conv = conversations_collection.find_one({"_id": ObjectId(msg.conversation_id)})
        if not conv:
            raise HTTPException(status_code=404, detail="Not found")
        
        # 2. Save Message with sender_name
        message_dict = msg.model_dump()
        message_dict.update({
            "sender_id": current_user_id,
            "sender_name": sender_name, # Stored for group chat identification
            "timestamp": datetime.utcnow(),
            "status": "sent",
            "is_deleted": False
        })
        messages_collection.insert_one(message_dict)
        preview_text = msg.text
        if not preview_text and hasattr(msg, "attachments") and msg.attachments:
            # Grab the first attachment URL
            first_url = msg.attachments[0]
            filename = first_url.split("/")[-1]
            name_part, ext_part = os.path.splitext(filename)
            
            # Strip the 8-character ID if it exists (-a1b2c3d4)
            if len(name_part) > 9 and name_part[-9] == "-":
                clean_name = name_part[:-9] + ext_part
            else:
                clean_name = filename
                
            # Set the inbox preview text
            preview_text = f"📎 {clean_name}"
        # 3. Update Conversation Meta
        update_query = {
            "$set": {
                "last_message": {
                    "text": preview_text,
                    "sender_id": current_user_id,
                    "timestamp": message_dict["timestamp"]
                }
            }
        }
        other_participants = [p for p in conv["participants"] if p != current_user_id]
        for p_id in other_participants:
            update_query.setdefault("$inc", {})[f"unread_counts.{p_id}"] = 1

        conversations_collection.update_one({"_id": ObjectId(msg.conversation_id)}, update_query)

        # 4. REAL-TIME: Broadcast with name
        ws_payload = {
            "type": "NEW_MESSAGE",
            "data": {
                "conversation_id": msg.conversation_id,
                "sender_id": current_user_id,
                "sender_name": sender_name, # Broadcast to update UI instantly
                "text": msg.text,
                "attachments": getattr(msg, "attachments", []),
                "timestamp": message_dict["timestamp"].isoformat()
            }
        }
        for p_id in conv["participants"]:
            await manager.send_to_user(ws_payload, p_id)

        return {"success": True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
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
@router.post("/course/{course_id}/join")
def join_course_chat(course_id: str, current_user_id: str = Depends(get_current_user)):
    try:
        # 1. Fetch proper course name for the group title
        course = courses_collection.find_one({"code": course_id})
        course_display_name = course.get("name", course_id) if course else course_id

        conv = conversations_collection.find_one({"course_id": course_id, "is_group": True})
        
        if conv:
            if current_user_id not in conv.get("participants", []):
                conversations_collection.update_one(
                    {"_id": conv["_id"]},
                    {
                        "$addToSet": {"participants": current_user_id},
                        "$set": {f"unread_counts.{current_user_id}": 0}
                    }
                )
            return {"success": True, "conversation_id": str(conv["_id"])}
        
        # 2. Create group with the Course Name as title
        new_conv = {
            "participants": [current_user_id],
            "created_at": datetime.utcnow(),
            "unread_counts": {current_user_id: 0},
            "last_message": None,
            "is_group": True,
            "course_id": course_id,
            "title": f"{course_display_name} Group" # Now uses course name
        }
        res = conversations_collection.insert_one(new_conv)
        return {"success": True, "conversation_id": str(res.inserted_id)}
        
    except Exception as e:
        LOGGER.error(f"Error joining: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

@router.post("/upload")
async def upload_attachment(
    request: Request,
    file: UploadFile = File(...), 
    current_user_id: str = Depends(get_current_user)
):
    LOGGER.info(f"User {current_user_id} initiated upload for file: {file.filename}")
    try:
        # 1. Clean the original filename (replace spaces with underscores to prevent URL issues)
        safe_original_name = file.filename.replace(" ", "_")
        
        # 2. Split the name and the extension (e.g., "Assignment-01" and ".pdf")
        name_part, ext_part = os.path.splitext(safe_original_name)
        
        # 3. Generate a short 8-character unique ID
        short_uuid = str(uuid.uuid4())[:8]
        
        # 4. Combine them: "Assignment-01-a1b2c3d4.pdf"
        unique_filename = f"{name_part}-{short_uuid}{ext_part}"
        
        file_path = os.path.join(UPLOAD_DIR, unique_filename)

        LOGGER.info(f"Saving file to disk at: {file_path}")

        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        base_url = str(request.base_url).rstrip("/")
        file_url = f"{base_url}/uploads/{unique_filename}"

        LOGGER.info(f"Successfully uploaded! Public URL generated: {file_url}")
        
        return {"success": True, "url": file_url}

    except Exception as e:
        LOGGER.error(f"Upload failed for user {current_user_id}. Error: {e}")
        raise HTTPException(status_code=500, detail="Could not upload file")