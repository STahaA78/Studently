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

# -------------------------------------------------
# STATIC ROUTES (NO path parameters)
# -------------------------------------------------

# 1. Search Users (Discover)
@router.get("/search/", response_model=list[UserOut])
def search_users(query: str = Query(..., min_length=1)):
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
        LOGGER.error(f"Search error: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")


# 2. Check Connection Status
@router.get("/status")
def check_connection_status(user_id: str, target_id: str):
    if not ObjectId.is_valid(user_id) or not ObjectId.is_valid(target_id):
        raise HTTPException(status_code=400, detail="Invalid ID")

    user = users_collection.find_one({"_id": ObjectId(user_id)})
    target = users_collection.find_one({"_id": ObjectId(target_id)})

    if not user or not target:
        raise HTTPException(status_code=404, detail="User not found")

    if target_id in user.get("friends", []):
        return {"status": "friends"}

    if target_id in user.get("friend_requests", []):
        return {"status": "incoming_request"}

    if user_id in target.get("friend_requests", []):
        return {"status": "outgoing_request"}

    return {"status": "none"}

# default discover users
@router.get("/discover", response_model=list[UserOut])
def discover_users(limit: int = 10):
    try:
        users = list(
            users_collection.aggregate([
                {"$sample": {"size": limit}}
            ])
        )
        return [fix_id(user) for user in users]
    except Exception as e:
        LOGGER.error(f"Discover error: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")


# -------------------------------------------------
# SEMI-DYNAMIC ROUTES ({user_id}/something)
# -------------------------------------------------

# 3. Send Friend Request
@router.post("/{user_id}/request")
def send_friend_request(user_id: str, target_id: str):
    if user_id == target_id:
        raise HTTPException(status_code=400, detail="Cannot connect with self")

    user = users_collection.find_one({"_id": ObjectId(user_id)})
    target = users_collection.find_one({"_id": ObjectId(target_id)})

    if not user or not target:
        raise HTTPException(status_code=404, detail="User not found")

    if target_id in user.get("friends", []):
        return {"success": False, "message": "Already friends"}

    if user_id in target.get("friend_requests", []):
        return {"success": False, "message": "Friend request already pending"}

    users_collection.update_one(
        {"_id": ObjectId(target_id)},
        {"$addToSet": {"friend_requests": user_id}}
    )

    return {"success": True, "message": "Friend request sent"}


# 4. Get Pending Friend Requests
@router.get("/{user_id}/requests", response_model=list[UserOut])
def get_pending_requests(user_id: str):
    if not ObjectId.is_valid(user_id):
        raise HTTPException(status_code=400, detail="Invalid ID")

    user = users_collection.find_one({"_id": ObjectId(user_id)})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    request_ids = user.get("friend_requests", [])
    if not request_ids:
        return []

    requesters = list(users_collection.find(
        {"_id": {"$in": [ObjectId(rid) for rid in request_ids]}}
    ))

    return [fix_id(req) for req in requesters]


# 5. Respond to Friend Request
@router.post("/{user_id}/respond")
def respond_to_friend_request(user_id: str, action_data: FriendRequestAction):
    if not ObjectId.is_valid(user_id) or not ObjectId.is_valid(action_data.requester_id):
        raise HTTPException(status_code=400, detail="Invalid ID")

    requester_id = action_data.requester_id
    action = action_data.action.lower()

    user = users_collection.find_one({"_id": ObjectId(user_id)})
    if not user or requester_id not in user.get("friend_requests", []):
        raise HTTPException(status_code=404, detail="Friend request not found")

    users_collection.update_one(
        {"_id": ObjectId(user_id)},
        {"$pull": {"friend_requests": requester_id}}
    )

    if action == "accept":
        users_collection.update_one(
            {"_id": ObjectId(user_id)},
            {"$addToSet": {"friends": requester_id}}
        )
        users_collection.update_one(
            {"_id": ObjectId(requester_id)},
            {"$addToSet": {"friends": user_id}}
        )
        return {"success": True, "message": "Friend request accepted"}

    elif action == "reject":
        return {"success": True, "message": "Friend request rejected"}

    else:
        raise HTTPException(status_code=400, detail="Invalid action")


# 6. Cancel Sent Friend Request
@router.post("/{user_id}/cancel-request")
def cancel_friend_request(user_id: str, target_id: str):
    if not ObjectId.is_valid(user_id) or not ObjectId.is_valid(target_id):
        raise HTTPException(status_code=400, detail="Invalid ID")

    result = users_collection.update_one(
        {"_id": ObjectId(target_id)},
        {"$pull": {"friend_requests": user_id}}
    )

    if result.modified_count == 0:
        return {"success": False, "message": "No pending request found"}

    return {"success": True, "message": "Friend request cancelled"}


# 7. Remove Friend
@router.post("/{user_id}/unfriend")
def remove_friend(user_id: str, action_data: FriendRemoveAction):
    if not ObjectId.is_valid(user_id) or not ObjectId.is_valid(action_data.friend_id):
        raise HTTPException(status_code=400, detail="Invalid ID")

    users_collection.update_one(
        {"_id": ObjectId(user_id)},
        {"$pull": {"friends": action_data.friend_id}}
    )
    users_collection.update_one(
        {"_id": ObjectId(action_data.friend_id)},
        {"$pull": {"friends": user_id}}
    )

    return {"success": True, "message": "Friend removed successfully"}


# 8. Get Friends
@router.get("/{user_id}/friends", response_model=list[UserOut])
def get_friends(user_id: str):
    if not ObjectId.is_valid(user_id):
        raise HTTPException(status_code=400, detail="Invalid ID")

    user = users_collection.find_one({"_id": ObjectId(user_id)})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    friend_ids = user.get("friends", [])
    if not friend_ids:
        return []

    friends = list(users_collection.find(
        {"_id": {"$in": [ObjectId(fid) for fid in friend_ids]}}
    ))

    return [fix_id(friend) for friend in friends]


# 9. Get Mutual Friends
@router.get("/{user_id}/mutual/{target_id}", response_model=list[UserOut])
def get_mutual_friends(user_id: str, target_id: str):
    if not ObjectId.is_valid(user_id) or not ObjectId.is_valid(target_id):
        raise HTTPException(status_code=400, detail="Invalid ID")

    user = users_collection.find_one({"_id": ObjectId(user_id)})
    target = users_collection.find_one({"_id": ObjectId(target_id)})

    if not user or not target:
        raise HTTPException(status_code=404, detail="User not found")

    mutual_ids = list(set(user.get("friends", [])) & set(target.get("friends", [])))
    if not mutual_ids:
        return []

    mutuals = list(users_collection.find(
        {"_id": {"$in": [ObjectId(fid) for fid in mutual_ids]}}
    ))

    return [fix_id(m) for m in mutuals]


# -------------------------------------------------
# FULLY DYNAMIC ROUTES (MUST BE LAST)
# -------------------------------------------------

# 10. Get User Profile
@router.get("/{user_id}", response_model=UserOut)
def get_profile(user_id: str):
    if not ObjectId.is_valid(user_id):
        raise HTTPException(status_code=400, detail="Invalid ID")

    user = users_collection.find_one({"_id": ObjectId(user_id)})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return fix_id(user)


# 11. Update Profile
@router.put("/{user_id}")
def update_profile(user_id: str, update_data: UserUpdate):
    if not ObjectId.is_valid(user_id):
        raise HTTPException(status_code=400, detail="Invalid ID")

    data = {k: v for k, v in update_data.model_dump().items() if v is not None}

    result = users_collection.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": data}
    )

    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="User not found")

    return {"success": True}
