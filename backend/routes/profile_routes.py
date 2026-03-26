from fastapi import APIRouter, HTTPException, Query
from database import users_collection
from models.user_model import UserOut, UserUpdate, FriendRequestAction, FriendRemoveAction
from bson import ObjectId
import logging

router = APIRouter()
LOGGER = logging.getLogger(__name__)
LOGGER.setLevel(logging.DEBUG)

def fix_id(doc):
    doc["id"] = str(doc.pop("_id"))
    return doc

# 1. Get User Profile
@router.get("/{user_id}", response_model=UserOut)
def get_profile(user_id: str):
        
    user = users_collection.find_one({"_id": user_id})
    if not user:
        LOGGER.error(f"Profile not found for id: {user_id}")
        raise HTTPException(status_code=404, detail="User not found")
    
    return fix_id(user)

# 2. Update Profile
@router.put("/{user_id}")
def update_profile(user_id: str, update_data: UserUpdate):
    LOGGER.info(f"Updating profile: {user_id}")
    try:
        data = {k: v for k, v in update_data.model_dump().items() if v is not None}
        
        result = users_collection.update_one(
            {"_id": user_id},
            {"$set": data}
        )
        
        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="User not found")
            
        return {"success": True}
    except Exception as e:
        LOGGER.error(f"Error updating profile: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

# 3. Search Users
@router.get("/search/", response_model=list[UserOut])
def search_users(query: str = Query(..., min_length=1)):
    LOGGER.debug(f"Searching users: {query}")
    try:
        regex_query = {"$regex": query, "$options": "i"}
        
        users = list(users_collection.find({
            "$or": [
                {"Name": regex_query},
                {"department": regex_query},
                {"interests": regex_query}
            ]
        }))
        
        return [fix_id(user) for user in users]
    except Exception as e:
        LOGGER.error(f"Error searching users: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

# 4. Send Friend Request
@router.post("/{user_id}/request")
def send_friend_request(user_id: str, target_id: str):
    if user_id == target_id:
        raise HTTPException(status_code=400, detail="Cannot connect with self")
    
    try:
        # Check if already friends
        user = users_collection.find_one({"_id": user_id})
        if target_id in user.get("friends", []):
            return {"success": False, "message": "Already friends"}

        # Add user_id to target's 'friend_requests' list
        result = users_collection.update_one(
            {"_id": target_id},
            {"$addToSet": {"friend_requests": user_id}}
        )
        
        if result.modified_count > 0:
            LOGGER.info(f"User {user_id} sent friend request to {target_id}")
            return {"success": True, "message": "Friend request sent"}
        else:
            return {"success": True, "message": "Request already sent"}
            
    except Exception as e:
        LOGGER.error(f"Error sending friend request: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

# 5. Get Pending Friend Requests
@router.get("/{user_id}/requests", response_model=list[UserOut])
def get_pending_requests(user_id: str):
    
    try:
        user = users_collection.find_one({"_id": user_id})
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
            
        request_ids = user.get("friend_requests", [])
        
        if not request_ids:
            return []
            
        # Fetch full profiles of requesters
        requesters = list(users_collection.find(
            {"_id": {"$in": [rid for rid in request_ids]}}
        ))
        
        return [fix_id(req) for req in requesters]
        
    except Exception as e:
        LOGGER.error(f"Error fetching requests: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

# 6. Respond to Friend Request (Accept/Reject) - UPDATED
@router.post("/{user_id}/respond")
def respond_to_friend_request(user_id: str, action_data: FriendRequestAction):
    
    requester_id = action_data.requester_id
    action = action_data.action.lower()
    
    try:
        # Check if the user exists and actually has a friend request from this requester
        user = users_collection.find_one({"_id": user_id})
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
            
        if requester_id not in user.get("friend_requests", []):
            raise HTTPException(status_code=404, detail="No friend request found from this user")

        # 1. Remove from friend_requests
        users_collection.update_one(
            {"_id": user_id},
            {"$pull": {"friend_requests": requester_id}}
        )
        
        if action == "accept":
            # 2. Add to friends list for BOTH users
            users_collection.update_one(
                {"_id": user_id},
                {"$addToSet": {"friends": requester_id}}
            )
            users_collection.update_one(
                {"_id": requester_id},
                {"$addToSet": {"friends": user_id}}
            )
            LOGGER.info(f"User {user_id} accepted request from {requester_id}")
            return {"success": True, "message": "Friend request accepted"}
            
        elif action == "reject":
            LOGGER.info(f"User {user_id} rejected request from {requester_id}")
            return {"success": True, "message": "Friend request rejected"}
            
        else:
            raise HTTPException(status_code=400, detail="Invalid action. Use 'accept' or 'reject'.")
            
    except HTTPException:
        raise
    except Exception as e:
        LOGGER.error(f"Error processing friend request response: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

# 7. Remove Friend (Unfriend) - NEW
@router.post("/{user_id}/unfriend")
def remove_friend(user_id: str, action_data: FriendRemoveAction):

        
    friend_id = action_data.friend_id
    
    try:
        # Remove friend_id from user's friend list
        res1 = users_collection.update_one(
            {"_id": user_id},
            {"$pull": {"friends": friend_id}}
        )
        
        # Remove user_id from friend's friend list
        res2 = users_collection.update_one(
            {"_id": friend_id},
            {"$pull": {"friends": user_id}}
        )
        
        if res1.modified_count == 0 and res2.modified_count == 0:
             return {"success": False, "message": "User was not in friend list"}

        LOGGER.info(f"User {user_id} removed friend {friend_id}")
        return {"success": True, "message": "Friend removed successfully"}
        
    except Exception as e:
        LOGGER.error(f"Error removing friend: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")