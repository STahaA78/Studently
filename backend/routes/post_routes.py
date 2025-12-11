from fastapi import APIRouter, HTTPException
from database import posts_collection, users_collection
from models.post_model import PostCreate, PostOut, CommentCreate
from bson import ObjectId
from datetime import datetime
import logging

router = APIRouter()
LOGGER = logging.getLogger(__name__)
LOGGER.setLevel(logging.DEBUG)

def fix_id(doc):
    doc["_id"] = str(doc["_id"])
    return doc

@router.get("/", response_model=list[PostOut])
def get_feed():
    LOGGER.info("Fetching Community Feed")
    try:
        posts = list(posts_collection.find().sort("timestamp", -1))
        return [fix_id(post) for post in posts]
    except Exception as e:
        LOGGER.error(f"Error fetching feed: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

@router.post("/", response_model=dict)
def create_post(post: PostCreate):
    LOGGER.info(f"Creating post for author: {post.author_id}")
    try:
        user = users_collection.find_one({"_id": ObjectId(post.author_id)})
        if not user:
            LOGGER.error(f"User not found: {post.author_id}")
            raise HTTPException(status_code=404, detail="User not found")
        
        new_post = post.model_dump()
        new_post["author_name"] = user.get("Name", "Unknown")
        new_post["author_pic"] = user.get("profile_picture")
        new_post["timestamp"] = datetime.utcnow()
        new_post["likes"] = []
        new_post["comments"] = []
        
        result = posts_collection.insert_one(new_post)
        LOGGER.info(f"Post created: {result.inserted_id}")
        return {"success": True, "id": str(result.inserted_id)}
    except Exception as e:
        LOGGER.error(f"Error creating post: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

@router.get("/{post_id}", response_model=PostOut)
def get_post_details(post_id: str):
    if not ObjectId.is_valid(post_id):
        raise HTTPException(status_code=400, detail="Invalid ID")
    
    post = posts_collection.find_one({"_id": ObjectId(post_id)})
    if not post:
        LOGGER.warning(f"Post not found: {post_id}")
        raise HTTPException(status_code=404, detail="Post not found")
    return fix_id(post)

@router.post("/{post_id}/like")
def like_post(post_id: str, user_id: str):
    if not ObjectId.is_valid(post_id):
        raise HTTPException(status_code=400, detail="Invalid ID")
    
    post = posts_collection.find_one({"_id": ObjectId(post_id)})
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")

    if user_id in post.get("likes", []):
        posts_collection.update_one({"_id": ObjectId(post_id)}, {"$pull": {"likes": user_id}})
        LOGGER.debug(f"User {user_id} unliked post {post_id}")
        return {"message": "Unliked"}
    else:
        posts_collection.update_one({"_id": ObjectId(post_id)}, {"$addToSet": {"likes": user_id}})
        LOGGER.debug(f"User {user_id} liked post {post_id}")
        return {"message": "Liked"}

@router.post("/{post_id}/comment")
def add_comment(post_id: str, comment: CommentCreate):
    if not ObjectId.is_valid(post_id):
        raise HTTPException(status_code=400, detail="Invalid Post ID")
    
    if not ObjectId.is_valid(comment.user_id):
        raise HTTPException(status_code=400, detail="Invalid User ID")

    try:
        # Fetch user to get the name
        user = users_collection.find_one({"_id": ObjectId(comment.user_id)})
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        # Create comment object
        comment_dict = comment.model_dump()
        comment_dict["username"] = user.get("Name", "Unknown") # Fetched from DB
        comment_dict["timestamp"] = datetime.utcnow()
        
        result = posts_collection.update_one(
            {"_id": ObjectId(post_id)},
            {"$push": {"comments": comment_dict}}
        )
        
        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="Post not found")
        
        LOGGER.info(f"Comment added to post {post_id} by {comment.user_id}")
        return {"success": True}
        
    except HTTPException:
        raise
    except Exception as e:
        LOGGER.error(f"Error adding comment: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")