# Endpoint to return profile photo
from fastapi.responses import FileResponse
import os
from fastapi import APIRouter, HTTPException, Depends, Query, Body, UploadFile, File, Request
from datetime import datetime
from database import users_collection, config_collection
from models.user_model import *
from utils.auth import get_current_user
import logging
import uuid
from datetime import datetime, timezone

router = APIRouter()
LOGGER = logging.getLogger(__name__)
# 3. Define your custom format (expects a 'uid' variable)
formatter = logging.Formatter(
    fmt="%(asctime)s | %(levelname)-8s | UID: [%(uid)s] | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
if not LOGGER.handlers:
    import sys
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(formatter)
    LOGGER.addHandler(handler)
    LOGGER.setLevel(logging.DEBUG)

# Helper to check if user is admin
def is_admin(user_id: str) -> bool:
    user = users_collection.find_one({"_id": user_id})
    if not user:
        return False
    # Check isAdmin field, default to False if missing
    return user.get("isAdmin", False)

#Create User
@router.post("/register")
def register(user: UserCreate):
    LOGGER.info("User Registration Started", extra={"uid": "Guest"})
    # Check if email is already taken
    if users_collection.find_one({"email": user.email.lower()}):
        raise HTTPException(status_code=400, detail="Email already registered")
    
    user_dict = user.model_dump()
    # Change: Use the provided uid or generate a new one if empty
    # We map this to '_id' so MongoDB uses it as the primary key
    user_id = user.uid if user.uid else str(uuid.uuid4())
    user_dict["_id"] = user_id
    user_dict["created_at"] = datetime.now(timezone.utc).replace(tzinfo=None)
    user_dict["email"] = user.email.lower()
    user_dict["birthday"] = datetime.combine(user.birthday, datetime.min.time())
    # interest validation 
    LOGGER.info(f"Validating interests for USER ID: {user_id} ", extra={"uid": user_id})
    user_interests = user_dict.get("interests", [])
    LOGGER.debug(f"User provided interests: {user_interests}", extra={"uid": user_id})
    if len(user_interests) > 5:
        LOGGER.warning(f"Too many interests: {len(user_interests)}", extra={"uid": user_id})
        raise HTTPException(status_code=400, detail="You can select up to 5 interests")
    app_config = config_collection.find_one({}, {"interests": 1, "_id": 0})
    LOGGER.debug(f"App config interests for validation: {app_config.get('interests', [])}", extra={"uid": user_id})
    if not app_config:
        raise HTTPException(status_code=500, detail="App configuration not found")
    
    # Build valid interests map (name -> emoji) for O(1) lookups
    valid_interests_map = {}
    for category in app_config.get("interests", []):
        for item in category.get("data", []):
            name = item.get("name")
            emoji = item.get("emoji")
            if name:
                valid_interests_map[name] = emoji
    
    verified_interests = []
    for interest in user_interests:
        # Extract interest name and emoji (handle both dict and object formats)
        interest_name = interest.get('name') if isinstance(interest, dict) else interest.name if hasattr(interest, 'name') else interest
        interest_emoji = interest.get('emoji') if isinstance(interest, dict) else interest.emoji if hasattr(interest, 'emoji') else None
        
        # Check for duplicates
        if interest_name in verified_interests:
            LOGGER.warning(f"Duplicate interest: {interest_name}", extra={"uid": user_id})
            raise HTTPException(status_code=400, detail=f"Duplicate interest: {interest_name}")
        
        # Validate name exists
        if interest_name not in valid_interests_map:
            LOGGER.warning(f"Invalid interest: {interest_name}", extra={"uid": user_id})
            raise HTTPException(status_code=400, detail=f"Invalid interest: {interest_name}")
        
        # Validate emoji matches
        if interest_emoji != valid_interests_map[interest_name]:
            LOGGER.warning(f"Invalid emoji for interest {interest_name}: got {interest_emoji}, expected {valid_interests_map[interest_name]}", extra={"uid": user_id})
            raise HTTPException(status_code=400, detail=f"Invalid emoji for interest: {interest_name}")
        
        verified_interests.append(interest_name)
    ###
    user_dict["friendsCount"] = 0
    if "uid" in user_dict:
        del user_dict["uid"]
    result = users_collection.insert_one(user_dict)
    LOGGER.info(f"User Registered Ended Successfully - id: {result.inserted_id}", extra={"uid": user_id})
    return {"success": True, "uid": str(result.inserted_id)}


#Login
@router.post("/login")
def login(user: UserLogin):
    LOGGER.info("User Login Started", extra={"uid": "Guest"})
    db_user = users_collection.find_one({"email": user.email.lower()})
    if not db_user:
        return {"success": False, "detail": "Invalid email or password"}
    # if not verify_password(user.password, db_user["password"]):
    #     return {"success": False, "detail": "Invalid email or password"}
    LOGGER.info(f"User Login Ended Successfully - id: {db_user['_id']}", extra={"uid": str(db_user["_id"])})
    # Return the uid (_id) so the frontend can track the session locally
    return {"success": True, "uid": str(db_user["_id"])}

@router.get("/{user_id}/profile", response_model=UserProfileData)
def get_user_info(user_id: str, USER: str = Depends(get_current_user)):
    LOGGER.info(f"Fetching profile for USER ID: {USER}", extra={"uid": USER})
    if user_id == "0":
        LOGGER.info(f"USER accessing own profile", extra={"uid": USER})
        user_id = USER  # Override to fetch own profile when user_id is "0"

    user_data = users_collection.find_one(
        {
            "_id": user_id
        },
        {
            "_id":1,
            "name": 1,
            "email": 1,
            "interests": 1,
            "department": 1,
            "batch": 1,
            "profilePhotoUrl":1,
            "friendsCount": 1
        }
    )
    LOGGER.debug(f"Database query result for user ID {user_id}: {user_data}", extra={"uid": USER})
    if not user_data:
        LOGGER.warning(f"User not found in DB for ID: {user_id}", extra={"uid": USER})
        raise HTTPException(status_code=404, detail="User not found")
    user_data["id"] = user_id # Insert id
    user_data["friendsCount"] = user_data.get("friendsCount", 0) # Add friends count
    LOGGER.info(f"Profile fetched successfully for user ID: {user_id}", extra={"uid": USER})
    return user_data


@router.get("/{user_id}/profile/photo")
def get_profile_photo(user_id: str, USER: str = Depends(get_current_user)):
    LOGGER.info(f"Fetching profile photo for USER ID: {user_id}", extra={"uid": USER})
    if user_id != "0":
        if is_admin(USER):
            LOGGER.info(f"Admin accessing profile photo of USER ID: {user_id}", extra={"uid": USER})
        else:
            LOGGER.warning(f"Unauthorized access attempt to profile photo of USER ID: {user_id} by USER ID: {USER}", extra={"uid": USER})
            raise HTTPException(status_code=403, detail="Not authorized to access this profile photo")
    else:
        LOGGER.info(f"USER accessing own profile photo", extra={"uid": USER})
        user_id = USER  # Override to fetch own profile photo when user_id is "0"
    user = users_collection.find_one({"_id": user_id})
    photo_path = user.get("profilePhotoPath")
    if not photo_path:
        LOGGER.warning(f"No Photo Path Found for USER ID: {user_id}", extra={"uid": USER})
        raise HTTPException(status_code=404, detail="Profile photo not set")
    file_path = os.path.join(os.getcwd(), photo_path.lstrip("/"))
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="Profile photo file not found")
    return FileResponse(file_path)

# Remove Profile Photo
@router.post("/{user_id}/profile/photo/remove")
def remove_profile_photo(user_id: str, USER: str = Depends(get_current_user)):
    if user_id != "0":
        if is_admin(USER):
            LOGGER.info(f"Admin accessing profile photo of USER ID: {user_id}", extra={"uid": USER})
        else:
            LOGGER.warning(f"Unauthorized access attempt to profile photo of USER ID: {user_id} by USER ID: {USER}", extra={"uid": USER})
            raise HTTPException(status_code=403, detail="Not authorized to remove this profile photo")
    else:
        user_id = USER
    user = users_collection.find_one({"_id": user_id})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    users_collection.update_one({"_id": user_id}, {"$set": {"profilePhotoPath": None,"profilePhotoUrl": None}})
    return {"success": True, "profile_photo_url": None}

# Add Profile Photo
@router.post("/{user_id}/profile/photo/add")
async def add_profile_photo(request: Request,user_id: str, photo: UploadFile = File(...), USER: str = Depends(get_current_user)):
    LOGGER.info(f"USER {USER} Add profile photo for USER ID: {user_id}", extra={"uid": USER})
    if user_id != "0":
        if is_admin(USER):
            LOGGER.info(f"Admin Add profile photo of USER ID: {user_id}", extra={"uid": USER})
        else:
            LOGGER.warning(f"Unauthorized update attempt to USER ID: {user_id} by USER ID: {USER}", extra={"uid": USER})
            raise HTTPException(status_code=403, detail="Not authorized to update this profile photo")
    else:
        LOGGER.info(f"USER Add own profile photo", extra={"uid": USER})
        user_id = USER  # Override to update own profile when user_id is "0"

    user = users_collection.find_one({"_id": user_id})
    if not user:
        LOGGER.warning(f"User not found in DB for ID: {user_id}", extra={"uid": USER})
        raise HTTPException(status_code=404, detail="User not found")

    # Save photo to disk (or cloud, here local for demo)
    try:
        photos_dir = "profile_photos"
        os.makedirs(photos_dir, exist_ok=True)
        _ , ext = os.path.splitext(photo.filename)
        filename = f"{user_id}{ext}"
        file_path = os.path.join(photos_dir, filename)
        with open(file_path, "wb") as f:
            content = await photo.read()
            f.write(content)
        # Store the file path or URL in DB
        photo_path = f"/{photos_dir}/{user_id}{ext}"
        base_url = str(request.base_url).rstrip('/')
        profile_photo_url = f"{base_url}/users/0/profile/photo"
        users_collection.update_one({"_id": user_id}, {"$set": {"profilePhotoPath": photo_path, "profilePhotoUrl": profile_photo_url}})
        LOGGER.info(f"Profile photo updated for user ID: {user_id}", extra={"uid": USER})
        return {"success": True, "message": "Photo Upload Successful"}
    except Exception as e:
        LOGGER.error(f"Error Uploading Profile Photo: {e}", extra={"uid": USER})
        raise HTTPException(status_code=500, detail="Internal Server Error")

@router.get("/search/", response_model=list[UserOut])
def search_users(limit: int = Query(10, ge=1, le=50),query: str = Query(..., min_length=1), USER: str = Depends(get_current_user)):
    LOGGER.info(f"Searching users with: {query}", extra={"uid": USER})
    regex_query = {"$regex": query, "$options": "i"}
    
    # Build search criteria - can search by name, department, interests, or roll number
    search_conditions = [
        {"name": regex_query},
        {"department": regex_query},
        {"interests": regex_query},
        {"email": {"$regex": f"^{query}", "$options": "i"}},  # Search by roll number (prefix of email)
    ]
    
    users = list(users_collection.find(
        {
            "_id": {"$ne": USER},   # exclude current user
            "$or": search_conditions
        },
        {
            "_id": 1,
            "email": 1,
            "name": 1,
            "department": 1,
            "batch": 1,
            "interests": 1
        }
    ).limit(limit))
    LOGGER.debug(f"Database search results for query '{query}': {users}",extra={"uid": USER})
    LOGGER.info(f"Search completed with {len(users)} results for query: {query}",extra={"uid": USER})
    return users

@router.post("/{user_id}/status", response_model=List[FriendStatus])
def check_connection_status(user_id: str, request: ConnectionStatusRequest, USER: str = Depends(get_current_user)):
    target_ids = request.target_ids
    LOGGER.info(f"Checking connection with {target_ids}", extra={"uid": USER})
    if user_id != "0":
        if is_admin(USER):
            LOGGER.info(f"Admin accessing  profile of USER ID: {user_id}", extra={"uid": USER})
        else:
            LOGGER.warning(f"Unauthorized access attempt to USER ID: {user_id} by USER ID: {USER}", extra={"uid": USER})
            raise HTTPException(status_code=403, detail="Not authorized to access this profile")
    else:
        LOGGER.info(f"USER accessing own profile", extra={"uid": USER})
        user_id = USER  # Override to fetch own profile when user_id is "0"
    
    user = users_collection.find_one({"_id": user_id})  # Ensure the requesting user exists in the database
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # 1. Fetch all targets into a list or dict immediately
    # This "drains" the cursor once and stores it in memory
    target_docs = list(users_collection.find({"_id": {"$in": target_ids}}))

    # 2. Create a lookup map for O(1) speed
    # This maps: {'id_123': {user_data}, 'id_456': {user_data}}
    target_map = {str(doc["_id"]): doc for doc in target_docs}

    friend_statuses = []

    # 3. Iterate through your IDs once and check the map
    for target_id in target_ids:
        target_user = target_map.get(target_id)
        
        if not target_user:
            LOGGER.warning(f"Target user not found: {target_id}")
            friend_statuses.append(FriendStatus(id=target_id, status="error"))
            continue
        
        # If found, check friendship status
        if target_id in user.get("friends", []):
            friend_statuses.append(FriendStatus(id=target_id, status="friends"))
        elif target_id in user.get("friend_requests", []):
            friend_statuses.append(FriendStatus(id=target_id, status="incoming_request"))
        elif user_id in target_user.get("friend_requests", []):
            friend_statuses.append(FriendStatus(id=target_id, status="outgoing_request"))
        else:
            friend_statuses.append(FriendStatus(id=target_id, status="none"))
    
    return friend_statuses

@router.get("/discover", response_model=list[UserOut])
def discover_users(
    limit: int = Query(10, ge=1, le=50),
    exclude: list[str] = Query(default=[]),
    USER: str = Depends(get_current_user)
):
    LOGGER.info(f"Discovering users", extra={"uid": USER})
    current_user = users_collection.find_one(
        {"_id": USER},
        {"friends": 1}
    )
    friends = current_user.get("friends", [])
    excluded_ids = list(set(friends + exclude + [USER]))
    pipeline = [
        {
            "$match": {
                "_id": {"$nin": excluded_ids}
            }
        },
        {"$sample": {"size": limit}},
        {
            "$project": {
                "id": "$_id",
                "name": 1,
                "email": 1,
                "department": 1,
                "batch": 1,
                "interests": 1
            }
        }
    ]

    users = list(users_collection.aggregate(pipeline))

    LOGGER.info(f"Discovery completed with {len(users)} users",extra={"uid": USER})
    return users

@router.post("/{user_id}/request")
def send_friend_request(user_id: str, target_id: str = Query(...), USER: str = Depends(get_current_user)):
    LOGGER.info(f"Sending friend request from {user_id} to {target_id}", extra={"uid": USER})
    if user_id != "0":
        if is_admin(USER):
            LOGGER.info(f"Admin accessing  profile of USER ID: {user_id}", extra={"uid": USER})
        else:
            LOGGER.warning(f"Unauthorized access attempt to USER ID: {user_id} by USER ID: {USER}", extra={"uid": USER})
            raise HTTPException(status_code=403, detail="Not authorized to access this profile")
    else:
        LOGGER.info(f"USER accessing own profile", extra={"uid": USER})
        user_id = USER  # Override to fetch own profile when user_id is "0"
    if user_id == target_id:
        LOGGER.warning(f"User {user_id} attempted to send friend request to self", extra={"uid": USER})
        raise HTTPException(status_code=400, detail="Cannot connect with self")

    user = users_collection.find_one({"_id": user_id})
    target = users_collection.find_one({"_id": target_id})

    if not user or not target:
        LOGGER.warning(f"User not found for either sender {user_id} or target {target_id}", extra={"uid": USER})
        raise HTTPException(status_code=404, detail="User not found")

    if target_id in user.get("friends", []):
        LOGGER.info(f"Users {user_id} and {target_id} are already friends", extra={"uid": USER})
        return {"success": False, "message": "Already friends"}

    users_collection.update_one(
        {"_id": target_id},
        {"$addToSet": {"friend_requests": user_id}}
    )
    LOGGER.info(f"Friend request sent from {user_id} to {target_id}", extra={"uid": USER})
    return {"success": True, "message": "Friend request sent"}


@router.get("/{user_id}/requests", response_model=list[UserOut])
def get_pending_requests(user_id:str, USER: str = Depends(get_current_user)):

    LOGGER.info(f"Fetching pending friend requests for USER {USER}", extra={"uid": USER})

    if user_id != "0":
        if is_admin(USER):
            LOGGER.info(f"Admin accessing  profile of USER ID: {user_id}", extra={"uid": USER})
        else:
            LOGGER.warning(f"Unauthorized access attempt to USER ID: {user_id} by USER ID: {USER}", extra={"uid": USER})
            raise HTTPException(status_code=403, detail="Not authorized to access this profile")
    else:
        LOGGER.info(f"USER accessing own profile", extra={"uid": USER})
        user_id = USER  # Override to fetch own profile when user_id is "0"
    
    user = users_collection.find_one({"_id": user_id})

    request_ids = user.get("friend_requests", [])
    if not request_ids:
        LOGGER.info(f"No pending friend requests for USER {USER}", extra={"uid": USER})
        return []

    requesters = list(users_collection.find(
        {"_id": {"$in": [rid for rid in request_ids]}}
    ))
    LOGGER.info(f"Found {len(requesters)} pending friend requests for USER {USER}", extra={"uid": USER})
    return requesters

@router.post("/{user_id}/respond")
def respond_to_friend_request(user_id: str, action_data: FriendRequestAction, USER : str = Depends(get_current_user)):
    LOGGER.info(f"USER {USER} responding to friend request for USER ID: {action_data.requester_id}", extra={"uid": USER})
    if user_id != "0":
        if is_admin(USER):
            LOGGER.info(f"Admin accessing  profile of USER ID: {user_id}", extra={"uid": USER})
        else:
            LOGGER.warning(f"Unauthorized access attempt to USER ID: {user_id} by USER ID: {USER}", extra={"uid": USER})
            raise HTTPException(status_code=403, detail="Not authorized to access this profile")
    else:
        LOGGER.info(f"USER accessing own profile", extra={"uid": USER})
        user_id = USER  # Override to fetch own profile when user_id is "0"
    
    user = users_collection.find_one({"_id": user_id})
    
    requester_id = action_data.requester_id
    action = action_data.action.lower()

    user = users_collection.find_one({"_id": user_id})
    if not user or requester_id not in user.get("friend_requests", []):
        LOGGER.warning(f"Friend request not found for USER {user_id} from requester {requester_id}", extra={"uid": user_id})
        raise HTTPException(status_code=404, detail="Friend request not found")

    users_collection.update_one(
        {"_id": user_id},
        {"$pull": {"friend_requests": requester_id}}
    )

    if action == "accept":
        users_collection.update_one(
            {"_id": user_id},
            {
                "$addToSet": {"friends": requester_id},
                "$inc": {"friendsCount": 1}
            }
        )
        users_collection.update_one(
            {"_id": requester_id},
            {
                "$addToSet": {"friends": user_id},
                "$inc": {"friendsCount": 1}
            }
        )
        LOGGER.info(f"Friend request accepted by USER {user_id} from requester {requester_id}", extra={"uid": user_id}) 
        return {"success": True, "message": "Friend request accepted"}
    elif action == "reject":
        LOGGER.info(f"Friend request rejected by USER {user_id} from requester {requester_id}", extra={"uid": user_id})
        return {"success": True, "message": "Friend request rejected"}
    else:
        LOGGER.warning(f"Invalid action '{action}' for USER {user_id} responding to requester {requester_id}", extra={"uid": user_id})
        raise HTTPException(status_code=400, detail="Invalid action")


@router.post("/{user_id}/cancel-request")
def cancel_friend_request(user_id: str, target_id: str, USER: str = Depends(get_current_user)):
    LOGGER.info(f"USER {USER} cancelling friend request to {target_id}", extra={"uid": USER})
    if user_id != "0":
        if is_admin(USER):
            LOGGER.info(f"Admin accessing  profile of USER ID: {user_id}", extra={"uid": USER})
        else:
            LOGGER.warning(f"Unauthorized access attempt to USER ID: {user_id} by USER ID: {USER}", extra={"uid": USER})
            raise HTTPException(status_code=403, detail="Not authorized to access this profile")
    else:
        LOGGER.info(f"USER accessing own profile", extra={"uid": USER})
        user_id = USER  # Override to fetch own profile when user_id is "0"
    users_collection.update_one(
        {"_id": target_id},
        {"$pull": {"friend_requests": user_id}}
    )
    LOGGER.info(f"Friend request from USER {user_id} to {target_id} cancelled", extra={"uid": USER})
    return {"success": True, "message": "Friend request cancelled"}


@router.post("/{user_id}/unfriend")
def remove_friend(user_id: str, action_data: FriendRemoveAction, USER: str = Depends(get_current_user)):
    LOGGER.info(f"USER {USER} removing friend {action_data.friend_id}", extra={"uid": USER})
    if user_id != "0":
        if is_admin(USER):
            LOGGER.info(f"Admin accessing  profile of USER ID: {user_id}", extra={"uid": USER})
        else:
            LOGGER.warning(f"Unauthorized access attempt to USER ID: {user_id} by USER ID: {USER}", extra={"uid": USER})
            raise HTTPException(status_code=403, detail="Not authorized to access this profile")
    else:
        LOGGER.info(f"USER accessing own profile", extra={"uid": USER})
        user_id = USER  # Override to fetch own profile when user_id is "0"

    users_collection.update_one(
        {"_id": user_id},
        {"$pull": {"friends": action_data.friend_id}}
    )
    users_collection.update_one(
        {"_id": action_data.friend_id},
        {"$pull": {"friends": user_id}}
    )
    LOGGER.info(f"USER {user_id} and {action_data.friend_id} are no longer friends", extra={"uid": USER})
    return {"success": True, "message": "Friend removed successfully"}

# Update User Profile
@router.patch("/{user_id}/update", response_model=UserProfileData)
def update_user_profile(user_id: str, updated_data: EditProfileData, USER: str = Depends(get_current_user)):
    LOGGER.info(f"USER {USER} updating profile for USER ID: {user_id}", extra={"uid": USER})
    if user_id != "0":
        if is_admin(USER):
            LOGGER.info(f"Admin updating profile of USER ID: {user_id}", extra={"uid": USER})
        else:
            LOGGER.warning(f"Unauthorized update attempt to USER ID: {user_id} by USER ID: {USER}", extra={"uid": USER})
            raise HTTPException(status_code=403, detail="Not authorized to update this profile")
    else:
        LOGGER.info(f"USER updating own profile", extra={"uid": USER})
        user_id = USER  # Override to update own profile when user_id is "0"

    user = users_collection.find_one({"_id": user_id})
    if not user:
        LOGGER.warning(f"User not found in DB for ID: {user_id}", extra={"uid": USER})
        raise HTTPException(status_code=404, detail="User not found")

    # Only allow updating certain fields
    if not updated_data:
        raise HTTPException(status_code=400, detail="No valid fields to update")

    # If interests are being updated, validate them
    if "interests" in updated_data:
    # interest validation 
        LOGGER.info(f"Validating interests for USER ID: {user_id} ", extra={"uid": user_id})
        user_interests = updated_data.get("interests", [])
        LOGGER.debug(f"User provided interests: {user_interests}", extra={"uid": user_id})
        if len(user_interests) > 5:
            LOGGER.warning(f"Too many interests: {len(user_interests)}", extra={"uid": user_id})
            raise HTTPException(status_code=400, detail="You can select up to 5 interests")
        app_config = config_collection.find_one({}, {"interests": 1, "_id": 0})
        if not app_config:
            raise HTTPException(status_code=500, detail="App configuration not found")
        # Build valid interests map (name -> emoji) for O(1) lookups
        valid_interests_map = {}
        for category in app_config.get("interests", []):
            for item in category.get("data", []):
                name = item.get("name")
                emoji = item.get("emoji")
                if name:
                    valid_interests_map[name] = emoji
        
        verified_interests = []
        for interest in user_interests:
            # Extract interest name and emoji (handle both dict and object formats)
            interest_name = interest.get('name') if isinstance(interest, dict) else interest.name if hasattr(interest, 'name') else interest
            interest_emoji = interest.get('emoji') if isinstance(interest, dict) else interest.emoji if hasattr(interest, 'emoji') else None
            
            # Check for duplicates
            if interest_name in verified_interests:
                LOGGER.warning(f"Duplicate interest: {interest_name}", extra={"uid": user_id})
                raise HTTPException(status_code=400, detail=f"Duplicate interest: {interest_name}")
            
            # Validate name exists
            if interest_name not in valid_interests_map:
                LOGGER.warning(f"Invalid interest: {interest_name}", extra={"uid": user_id})
                raise HTTPException(status_code=400, detail=f"Invalid interest: {interest_name}")
            
            # Validate emoji matches
            if interest_emoji != valid_interests_map[interest_name]:
                LOGGER.warning(f"Invalid emoji for interest {interest_name}: got {interest_emoji}, expected {valid_interests_map[interest_name]}", extra={"uid": user_id})
                raise HTTPException(status_code=400, detail=f"Invalid emoji for interest: {interest_name}")
            
            verified_interests.append(interest_name)
            
    users_collection.update_one({"_id": user_id}, {"$set": updated_data.model_dump(exclude_unset=True)})
    LOGGER.info(f"Profile updated successfully for user ID: {user_id}", extra={"uid": USER})
    # Return updated profile
    updated_user = users_collection.find_one({"_id": user_id}, {
        "name": 1,
        "email": 1,
        "interests": 1,
        "department": 1,
        "batch": 1,
        "friendsCount": 1
    })
    updated_user["id"] = user_id
    return updated_user

@router.get("/{user_id}/friends_list", response_model=list[UserOut])
def get_friends_list(user_id: str, USER: str = Depends(get_current_user)):  
    LOGGER.info(f"Fetching friends list for USER ID: {user_id}", extra={"uid": USER})
    if user_id != "0":
        if is_admin(USER):
            LOGGER.info(f"Admin accessing  profile of USER ID: {user_id}", extra={"uid": USER})
        else:
            LOGGER.warning(f"Unauthorized access attempt to USER ID: {user_id} by USER ID: {USER}", extra={"uid": USER})
            raise HTTPException(status_code=403, detail="Not authorized to access this profile")
    else:
        LOGGER.info(f"USER accessing own profile", extra={"uid": USER})
        user_id = USER  # Override to fetch own profile when user_id is "0"
    user = users_collection.find_one({"_id": user_id})
    friend_ids = user.get("friends", [])
    if not friend_ids:
        LOGGER.info(f"No friends found for USER ID: {user_id}", extra={"uid": USER})
        return []
    friends = list(users_collection.find(
        {"_id": {"$in": friend_ids}},
        {
            "_id": 1,
            "name": 1,
            "email": 1,
            "department": 1,
            "batch": 1,
            "interests": 1
        }
    ))
    for friend in friends:
        friend["id"] = friend["_id"]
    LOGGER.info(f"Found {len(friends)} friends for USER ID: {user_id}", extra={"uid": USER})
    return friends