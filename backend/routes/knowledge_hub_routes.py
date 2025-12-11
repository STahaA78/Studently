from fastapi import APIRouter, HTTPException, Query
from database import knowledge_hub_collection, users_collection
from models.knowledge_hub_model import ResourceCreate, ResourceOut, CourseSummary, ResourceUpdate
from bson import ObjectId
from datetime import datetime
from typing import Optional, List
import logging

router = APIRouter()
LOGGER = logging.getLogger(__name__)
LOGGER.setLevel(logging.DEBUG)

def fix_id(doc):
    doc["_id"] = str(doc["_id"])
    return doc

# Helper to check if user is admin
def is_admin(user_id: str) -> bool:
    if not ObjectId.is_valid(user_id):
        return False
    user = users_collection.find_one({"_id": ObjectId(user_id)})
    if not user:
        return False
    # Check isAdmin field, default to False if missing
    return user.get("isAdmin", False)

# ---------------------------------------------------------
# Knowledge Hub Screen (List Courses & Search)
# ---------------------------------------------------------

@router.get("/courses", response_model=list[CourseSummary])
def get_all_courses():
    LOGGER.info("Fetching all courses with resources")
    try:
        pipeline = [
            {"$match": {"approved": True}},
            {
                "$group": {
                    "_id": "$course_code",
                    "course_name": {"$first": "$course_name"},
                    "resource_count": {"$sum": 1}
                }
            },
            {"$sort": {"_id": 1}}
        ]
        
        results = list(knowledge_hub_collection.aggregate(pipeline))
        
        courses = []
        for r in results:
            courses.append(CourseSummary(
                course_code=r["_id"],
                course_name=r["course_name"],
                resource_count=r["resource_count"]
            ))
            
        return courses
    except Exception as e:
        LOGGER.error(f"Error fetching courses: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

@router.get("/search", response_model=list[ResourceOut])
def search_resources(query: str = Query(..., min_length=1)):
    LOGGER.debug(f"Searching resources with query: {query}")
    try:
        regex_query = {"$regex": query, "$options": "i"}
        
        resources = list(knowledge_hub_collection.find({
            "approved": True,
            "$or": [
                {"course_code": regex_query},
                {"course_name": regex_query},
                {"file_name": regex_query},
                {"tags": regex_query}
            ]
        }))
        
        return [fix_id(res) for res in resources]
    except Exception as e:
        LOGGER.error(f"Error searching resources: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

# ---------------------------------------------------------
# Repository User View (View Files for a Course)
# ---------------------------------------------------------

@router.get("/course/{course_code}", response_model=list[ResourceOut])
def get_course_resources(course_code: str, file_type: Optional[str] = None):
    LOGGER.debug(f"Fetching resources for course: {course_code}")
    try:
        query = {
            "course_code": course_code, 
            "approved": True
        }
        
        if file_type:
            query["file_type"] = file_type
            
        resources = list(knowledge_hub_collection.find(query).sort("uploaded_at", -1))
        return [fix_id(res) for res in resources]
    except Exception as e:
        LOGGER.error(f"Error fetching course resources: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

@router.post("/upload", response_model=dict)
def upload_resource(resource: ResourceCreate):
    LOGGER.info(f"User {resource.uploaded_by} uploading file: {resource.file_name}")
    try:
        if not users_collection.find_one({"_id": ObjectId(resource.uploaded_by)}):
            raise HTTPException(status_code=404, detail="User not found")

        resource_dict = resource.model_dump()
        resource_dict["uploaded_at"] = datetime.utcnow()
        resource_dict["approved"] = False  
        resource_dict["download_count"] = 0
        
        result = knowledge_hub_collection.insert_one(resource_dict)
        LOGGER.info(f"Resource uploaded successfully: {result.inserted_id}")
        
        return {"success": True, "id": str(result.inserted_id), "message": "Upload submitted for review"}
    except HTTPException:
        raise
    except Exception as e:
        LOGGER.error(f"Error uploading resource: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

# ---------------------------------------------------------
# Management APIs (Approve, Reject, Update, Delete)
# ---------------------------------------------------------

@router.get("/admin/pending", response_model=list[ResourceOut])
def get_pending_resources(user_id: str):
    """
    Fetches pending resources. Requires Admin Access.
    """
    if not is_admin(user_id):
        raise HTTPException(status_code=403, detail="Access Forbidden: Admins only")

    LOGGER.info("Fetching pending resources for admin")
    try:
        resources = list(knowledge_hub_collection.find({"approved": False}).sort("uploaded_at", 1))
        return [fix_id(res) for res in resources]
    except Exception as e:
        LOGGER.error(f"Error fetching pending resources: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

@router.post("/admin/{resource_id}/approve")
def approve_resource(resource_id: str, user_id: str):
    """
    Approves a resource. Checks if the logged-in user is an Admin.
    """
    if not ObjectId.is_valid(resource_id):
        raise HTTPException(status_code=400, detail="Invalid ID")

    # 1. Check Admin Status
    if not is_admin(user_id):
        LOGGER.warning(f"User {user_id} attempted to approve resource without admin privileges")
        raise HTTPException(status_code=403, detail="Access Forbidden: Admins only")
        
    try:
        resource = knowledge_hub_collection.find_one({"_id": ObjectId(resource_id)})
        if not resource:
            raise HTTPException(status_code=404, detail="Resource not found")
            
        if resource.get("approved") is True:
            return {"success": False, "message": "Resource is already approved"}

        result = knowledge_hub_collection.update_one(
            {"_id": ObjectId(resource_id)},
            {"$set": {"approved": True}}
        )
        
        LOGGER.info(f"Resource {resource_id} approved by admin {user_id}")
        return {"success": True, "message": "Resource approved"}
        
    except HTTPException:
        raise
    except Exception as e:
        LOGGER.error(f"Error approving resource: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

@router.delete("/admin/{resource_id}/reject")
def reject_resource(resource_id: str, user_id: str):
    """
    Rejects (deletes) a pending resource. Checks if the logged-in user is an Admin.
    """
    if not ObjectId.is_valid(resource_id):
        raise HTTPException(status_code=400, detail="Invalid ID")

    # 1. Check Admin Status
    if not is_admin(user_id):
        LOGGER.warning(f"User {user_id} attempted to reject resource without admin privileges")
        raise HTTPException(status_code=403, detail="Access Forbidden: Admins only")
        
    try:
        resource = knowledge_hub_collection.find_one({"_id": ObjectId(resource_id)})
        if not resource:
            raise HTTPException(status_code=404, detail="Resource not found")
            
        if resource.get("approved") is True:
            raise HTTPException(status_code=400, detail="Cannot reject an already approved resource. Use delete.")

        knowledge_hub_collection.delete_one({"_id": ObjectId(resource_id)})
        LOGGER.info(f"Resource {resource_id} rejected by admin {user_id}")
        return {"success": True, "message": "Resource rejected and removed"}
        
    except HTTPException:
        raise
    except Exception as e:
        LOGGER.error(f"Error rejecting resource: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

@router.put("/resource/{resource_id}")
def update_resource(resource_id: str, user_id: str, update_data: ResourceUpdate):
    """
    Updates details of a resource. 
    Only the Uploader or an Admin can update.
    """
    if not ObjectId.is_valid(resource_id):
        raise HTTPException(status_code=400, detail="Invalid ID")
        
    try:
        resource = knowledge_hub_collection.find_one({"_id": ObjectId(resource_id)})
        if not resource:
            raise HTTPException(status_code=404, detail="Resource not found")

        # Check permission: Must be Uploader or Admin
        if resource.get("uploaded_by") != user_id and not is_admin(user_id):
            raise HTTPException(status_code=403, detail="Permission denied")

        data = {k: v for k, v in update_data.model_dump().items() if v is not None}
        
        result = knowledge_hub_collection.update_one(
            {"_id": ObjectId(resource_id)},
            {"$set": data}
        )
        
        LOGGER.info(f"Resource {resource_id} updated by {user_id}")
        return {"success": True, "message": "Resource updated successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        LOGGER.error(f"Error updating resource: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

@router.delete("/resource/{resource_id}")
def delete_resource(resource_id: str, user_id: str):
    """
    Permanently deletes a resource. 
    Only the Uploader or an Admin can delete.
    """
    if not ObjectId.is_valid(resource_id):
        raise HTTPException(status_code=400, detail="Invalid ID")
        
    try:
        resource = knowledge_hub_collection.find_one({"_id": ObjectId(resource_id)})
        if not resource:
            raise HTTPException(status_code=404, detail="Resource not found")

        # Check permission: Must be Uploader or Admin
        if resource.get("uploaded_by") != user_id and not is_admin(user_id):
            raise HTTPException(status_code=403, detail="Permission denied")

        result = knowledge_hub_collection.delete_one({"_id": ObjectId(resource_id)})
        
        LOGGER.info(f"Resource {resource_id} deleted by {user_id}")
        return {"success": True, "message": "Resource deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        LOGGER.error(f"Error deleting resource: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")