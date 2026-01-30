from fastapi import APIRouter, HTTPException, Query, Depends, UploadFile, File
from database import knowledge_hub_collection, users_collection, courses_collection
from models.knowledge_hub_model import *
from bson import ObjectId
from datetime import datetime, timezone
from typing import Optional, List
import logging
import os
import uuid

router = APIRouter()
LOGGER = logging.getLogger(__name__)

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

@router.get("/courses", response_model=List[CourseMetadata])
def get_all_courses():
    """
    Fetches all unique courses (code and name) from approved resources.
    """
    LOGGER.info("Get All Courses Initiated")
    try:
        results = list(courses_collection.find({
            "course_code": {"$type": "string"},
            "course_name": {"$type": "string"}
        },{"_id": 0}).sort("course_name", 1))
        LOGGER.info(f"Get All Courses Ended Successfully. {len(results)} courses")
        return results
    except Exception as e:
        LOGGER.info("Get All Courses Failed")
        LOGGER.error(f"Error fetching courses: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

# Upload Endpoint
@router.post("/upload",response_model=UploadResponse)
async def upload_resource(
    meta: ResourceInMetadata = Depends(),
    file: UploadFile = File(...)
):
    """
    Uploads a resource to the Knowledge Hub.
    """
    LOGGER.info(f"Resource Upload Initiated.")
    resource_dict = meta.model_dump(exclude_none=True, exclude_unset=True)
    LOGGER.debug(f"Upload Metadata: {resource_dict}")
    try:
        # if not users_collection.find_one({"_id": ObjectId(meta.uploaded_by)}):
        #     raise HTTPException(status_code=404, detail="User not found")
        
        # Write File Upload Logic Here (e.g., to S3, local storage, etc.)
        base_folder = 'resources'
        path_parts = [base_folder, meta.course_code]
        if meta.resource_type == 'book':
            path_parts.append('books')
        else:
            path_parts.append(f"{meta.year}")
            path_parts.append(f"{meta.semester}")
            path_parts.append(f"{meta.resource_type}s")
            if meta.resource_type == 'quiz':
                path_parts.append(f"{meta.instructor_name}")

        folder_path = os.path.join(*path_parts)
        os.makedirs(folder_path, exist_ok=True)

        _, ext = os.path.splitext(file.filename)
        filename = f"{uuid.uuid4()}{ext}"
        file_path = os.path.join(folder_path, filename)

        # Stream File
        with open(file_path, "wb") as f:
            while chunk := await file.read(1024 * 1024):  # 1 MB chunks
                f.write(chunk)

        resource_dict['file_path'] = file_path
        # ---
        resource_dict['uploaded_at'] = datetime.now(timezone.utc)
        resource_dict['approved'] = False  # New uploads require approval
        resource_dict['download_count'] = 0

        result = knowledge_hub_collection.insert_one(resource_dict)

        LOGGER.info(f"Resource Upload Ended successfully: {result.inserted_id}")
        return UploadResponse(
            message="Upload Successful", resource_id=str(result.inserted_id)
        )
    except HTTPException as he:
        LOGGER.error(f"Resource Upload Failed. HTTP Exception occurred: {he}", exc_info=True)
        raise he
    except Exception as e:
        LOGGER.error(f"Resource Upload Failed. Error uploading resource: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Internal Server Error")

###################################
#  Resource APIs
###################################

@router.get("/resource", response_model=List[ResourceGroup])
def get_all_resources():
    """
    Fetches all approved resources grouped by course.
    """
    LOGGER.info("Fetching All Approved resources")
    try:
        pipeline = [
            # Only approved resources
            {"$match": {"approved": True}},

            # Group by course
            {
                "$group": {
                    "_id": {
                        "course_code": "$course_code",
                        "course_name": "$course_name",
                    },
                    "resources": {
                        "$push": {
                            "id": { "$toString": "$_id" },
                            "year": "$year",
                            "semester": "$semester",
                            "resource_type": "$resource_type",
                            "instructor_name": "$instructor_name",
                            "quiz_number": "$quiz_number",
                            "file_path": "$file_path",
                            "uploaded_at": "$uploaded_at",
                        }
                    }
                }
            },

            # Shape output
            {
                "$project": {
                    "_id": 0,
                    "course_code": "$_id.course_code",
                    "course_name": "$_id.course_name",
                    "resources": 1
                }
            },

            # Sort by course name
            {"$sort": {"course_name": 1}}
        ]

        results = list(knowledge_hub_collection.aggregate(pipeline))
        return results

    except Exception as e:
        LOGGER.error(f"Error fetching resources: {e}", exc_info=True)
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
    

# ---------------------------------------------------------
# Management APIs (Approve, Reject, Update, Delete)
# ---------------------------------------------------------

# @router.get("/admin/pending", response_model=ListResources)
# def get_pending_resources(user_id: str):
#     """
#     Fetches pending resources. Requires Admin Access.
#     """
#     if not is_admin(user_id):
#         raise HTTPException(status_code=403, detail="Access Forbidden: Admins only")

#     LOGGER.info("Fetching pending resources for admin")
#     try:
#         resources = list(knowledge_hub_collection.find({"approved": False}).sort("uploaded_at", 1))
#         return ListResources(resources=[fix_id(res) for res in resources])
#     except Exception as e:
#         LOGGER.error(f"Error fetching pending resources: {e}")
#         raise HTTPException(status_code=500, detail="Internal Server Error")

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
