from fastapi import APIRouter, HTTPException, Depends, Query, UploadFile, File, Form
from database import posts_collection, users_collection
from models.post_model import PostCreate, PostOut, CommentCreate, PostUpdate
from utils.auth import get_current_user
from bson import ObjectId
from datetime import datetime, timezone
import logging
import os
import shutil
import uuid

router = APIRouter()

LOGGER = logging.getLogger(__name__)
LOGGER.setLevel(logging.DEBUG)


def fix_id(doc):
    doc["id"] = str(doc.pop("_id"))
    doc["content"] = doc.get("content") or ""
    doc["mrdia_urls"] = doc.get("media_urls") or []
    doc["likes"] = doc.get("likes") or []
    doc["comments"] = doc.get("comments") or []
    return doc


# ================================
# Get Community Feed
# ================================
@router.get("/", response_model=list[PostOut])
def get_feed(
    user: str = Depends(get_current_user),
    limit: int = Query(10, ge=1, le=50),
    skip: int = Query(0, ge=0)
):

    LOGGER.info(f"Fetching Community Feed for user {user} | limit={limit} skip={skip}")

    try:

        posts = list(
            posts_collection
            .find()
            .sort("timestamp", -1)
            .skip(skip)
            .limit(limit)
        )

        return [fix_id(post) for post in posts]

    except Exception as e:

        LOGGER.error(f"Error fetching feed: {e}")

        raise HTTPException(status_code=500, detail="Internal Server Error")


# ================================
# Create Post
# ================================
UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)


@router.post("/", response_model=dict)
async def create_post(
    content: str | None = Form(None),
    file: UploadFile | None = File(None),
    user: str = Depends(get_current_user)
):

    if not content and not file:
        raise HTTPException(status_code=400, detail="Post must contain text or image")

    LOGGER.info(f"Creating post for user {user}")

    try:

        db_user = users_collection.find_one({"_id": user})

        if not db_user:
            raise HTTPException(status_code=404, detail="User not found")

        media_urls = []

        # Save image
        if file:

            filename = f"{uuid.uuid4()}_{file.filename}"

            file_path = f"{UPLOAD_DIR}/{filename}"

            with open(file_path, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)

            media_urls.append(f"/uploads/{filename}")

        new_post = {

            "author_id": user,
            "author_name": db_user.get("Name", "Unknown"),
            "author_pic": db_user.get("profile_picture"),

            "content": content or "",

            "media_urls": media_urls,

            "likes": [],
            "comments": [],

            "timestamp": datetime.now(timezone.utc).isoformat()

        }

        result = posts_collection.insert_one(new_post)

        LOGGER.info(f"Post created successfully: {result.inserted_id}")

        return {
            "success": True,
            "id": str(result.inserted_id)
        }

    except Exception as e:

        LOGGER.error(f"Error creating post: {e}")

        raise HTTPException(status_code=500, detail="Internal Server Error")


# ================================
# Get Post Details
# ================================
@router.get("/{post_id}", response_model=PostOut)
def get_post_details(
    post_id: str,
    user: str = Depends(get_current_user),
    comment_limit: int = Query(5, ge=1, le=50),
    comment_skip: int = Query(0, ge=0)
):

    if not ObjectId.is_valid(post_id):
        raise HTTPException(status_code=400, detail="Invalid ID")

    post = posts_collection.find_one({"_id": ObjectId(post_id)})

    if not post:
        raise HTTPException(status_code=404, detail="Post not found")

    comments = post.get("comments", [])

    paginated_comments = comments[comment_skip: comment_skip + comment_limit]

    post["comments"] = paginated_comments

    return fix_id(post)


# ================================
# Like / Unlike Post
# ================================
@router.post("/{post_id}/like")
def like_post(post_id: str, user: str = Depends(get_current_user)):

    if not ObjectId.is_valid(post_id):
        raise HTTPException(status_code=400, detail="Invalid ID")

    post = posts_collection.find_one({"_id": ObjectId(post_id)})

    if not post:
        raise HTTPException(status_code=404, detail="Post not found")

    if user in post.get("likes", []):

        posts_collection.update_one(
            {"_id": ObjectId(post_id)},
            {"$pull": {"likes": user}}
        )

        return {"message": "Unliked"}

    else:

        posts_collection.update_one(
            {"_id": ObjectId(post_id)},
            {"$addToSet": {"likes": user}}
        )

        return {"message": "Liked"}


# ================================
# Add Comment
# ================================
@router.post("/{post_id}/comment")
def add_comment(post_id: str, comment: CommentCreate, user: str = Depends(get_current_user)):

    if not ObjectId.is_valid(post_id):
        raise HTTPException(status_code=400, detail="Invalid Post ID")

    db_user = users_collection.find_one({"_id": user})

    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")

    comment_dict = comment.model_dump()

    comment_dict["user_id"] = user
    comment_dict["username"] = db_user.get("Name", "Unknown")
    comment_dict["timestamp"] = datetime.now(timezone.utc).isoformat()

    posts_collection.update_one(
        {"_id": ObjectId(post_id)},
        {"$push": {"comments": comment_dict}}
    )

    return {"success": True, "comment": comment_dict}


# ================================
# Delete Post
# ================================
@router.delete("/{post_id}")
def delete_post(post_id: str, user: str = Depends(get_current_user)):

    if not ObjectId.is_valid(post_id):
        raise HTTPException(status_code=400, detail="Invalid Post ID")

    post = posts_collection.find_one({"_id": ObjectId(post_id)})

    if not post:
        raise HTTPException(status_code=404, detail="Post not found")

    if post.get("author_id") != user:
        raise HTTPException(status_code=403, detail="Not authorized")

    posts_collection.delete_one({"_id": ObjectId(post_id)})

    return {"success": True, "message": "Post deleted"}


# ================================
# Edit Post
# ================================
@router.put("/{post_id}")
def edit_post(post_id: str, post_update: PostUpdate, user: str = Depends(get_current_user)):

    if not ObjectId.is_valid(post_id):
        raise HTTPException(status_code=400, detail="Invalid Post ID")

    post = posts_collection.find_one({"_id": ObjectId(post_id)})

    if not post:
        raise HTTPException(status_code=404, detail="Post not found")

    if post.get("author_id") != user:
        raise HTTPException(status_code=403, detail="Not authorized")

    posts_collection.update_one(
        {"_id": ObjectId(post_id)},
        {"$set": {"content": post_update.content}}
    )

    return {"success": True, "message": "Post updated"}


# ================================
# Delete Comment
# ================================
@router.delete("/{post_id}/comment/{comment_index}")
def delete_comment(post_id: str, comment_index: int, user: str = Depends(get_current_user)):

    if not ObjectId.is_valid(post_id):
        raise HTTPException(status_code=400, detail="Invalid Post ID")

    post = posts_collection.find_one({"_id": ObjectId(post_id)})

    if not post:
        raise HTTPException(status_code=404, detail="Post not found")

    comments = post.get("comments", [])

    if comment_index >= len(comments):
        raise HTTPException(status_code=404, detail="Comment not found")

    comment = comments[comment_index]

    if comment["user_id"] != user:
        raise HTTPException(status_code=403, detail="Not allowed")

    posts_collection.update_one(
        {"_id": ObjectId(post_id)},
        {"$pull": {"comments": comment}}
    )

    return {"success": True}