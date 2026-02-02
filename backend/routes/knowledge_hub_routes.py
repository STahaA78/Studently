from fastapi import APIRouter, HTTPException, Query, Depends, UploadFile, File, Form
from database import users_collection, courses_collection, resources_collection
from models.knowledge_hub_model import *
from bson import ObjectId
from datetime import datetime, timezone
from typing import Optional, List
import logging
import os
import uuid
from jsonschema import ValidationError

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

@router.get("/courses", response_model=List[Course])
def get_all_courses():
    """
    Fetches all unique courses (code and name) from approved resources.
    """
    LOGGER.info("Get All Courses Initiated")
    try:
        results = list(courses_collection.find({},{"_id": 0}).sort("name", 1))
        LOGGER.info(f"Get All Courses Ended Successfully. {len(results)} courses")
        return results
    except Exception as e:
        LOGGER.info("Get All Courses Failed")
        LOGGER.error(f"Error fetching courses: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

# Upload Endpoint
@router.post("/upload",response_model=UploadResponse)
async def upload_resource(
    metadata: str = Form(...),
    file: UploadFile = File(...)
):
    """
    Uploads a resource to the Knowledge Hub.
    """
    LOGGER.info(f"Resource Upload Initiated.")
    try:
        meta_model = ResourceInMetadata.model_validate_json(metadata)
    except ValidationError as ve:
        raise HTTPException(status_code=422, detail=ve.errors())
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid JSON in meta")
    meta_dict = meta_model.model_dump(exclude_none=True, exclude_unset=True)

    LOGGER.debug(f"Upload Metadata: {meta_dict}")
    try:
        # if not users_collection.find_one({"_id": ObjectId(meta.uploaded_by)}):
        #     raise HTTPException(status_code=404, detail="User not found")
        
        # Write File Upload Logic Here (e.g., to S3, local storage, etc.)
        base_folder = 'resources'
        path_parts = [base_folder, meta_dict['course']['code']]
        if meta_dict['type'] == 'book':
            path_parts.append('books')
        else:
            path_parts.append(f"{meta_dict['year']}")
            path_parts.append(f"{meta_dict['semester']}")
            path_parts.append(f"{meta_dict['type']}s")
            if meta_dict['type'] == 'quiz':
                path_parts.append(f"{meta_dict['instructorName']}")

        folder_path = os.path.join(*path_parts)
        os.makedirs(folder_path, exist_ok=True)

        _, ext = os.path.splitext(file.filename)
        filename = f"{uuid.uuid4()}{ext}"
        file_path = os.path.join(folder_path, filename)

        # Stream File
        with open(file_path, "wb") as f:
            while chunk := await file.read(1024 * 1024):  # 1 MB chunks
                f.write(chunk)

        meta_dict['filePath'] = file_path
        # ---
        meta_dict['uploadedAt'] = datetime.now(timezone.utc)
        meta_dict['approved'] = False  # New uploads require approval
        meta_dict['downloadCount'] = 0
        result = resources_collection.insert_one(meta_dict)

        LOGGER.info(f"Resource Upload Ended successfully: {result.inserted_id}")
        return UploadResponse(
            message="Upload Successful", resourceId=str(result.inserted_id)
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

@router.get("/resources", response_model=List[ResourceGroup])
def get_all_resources():
    """
    Fetches all approved resources grouped by course.
    """
    LOGGER.info("Fetching All Approved resources")
    try:
        pipeline = [
            # 1. Match only approved resources
            {"$match": {"approved": True}},

            # 2. First Group: Bundle items by Course AND Type
            {
                "$group": {
                    "_id": {
                        "course": "$course",
                        "type": "$type"
                    },
                    "items": {
                        "$push": {
                            "id": {"$toString": "$_id"},
                            "year": "$year",
                            "semester": "$semester",
                            "instructorName": "$instructorName",
                            "quizNumber": "$quizNumber",
                            "filePath": "$filePath",
                            "uploadedAt": "$uploadedAt",
                        }
                    }
                }
            },
            {
                "$group": {
                    "_id": "$_id.course",
                    "cat_list": {
                        "$push": {
                            "k": "$_id.type", 
                            "v": "$items"
                        }
                    }
                }
            },
            # 4. Convert that list into a single Object/Map
            {
                "$project": {
                    "_id": 0,
                    "course": "$_id",
                    "categories": { "$arrayToObject": "$cat_list" }
                }
            },
            # 5. Sort by course name
            {"$sort": {"course.name": 1}}
        ]

        results = list(resources_collection.aggregate(pipeline))
        LOGGER.info(f"Fetched {len(results)} resource groups")
        LOGGER.debug(f"Resource Data: {results}")
        LOGGER.info("Ended fetching all resources successfully")
        return results

    except Exception as e:
        LOGGER.error(f"Error fetching resources: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Internal Server Error")

@router.get("/resources/{course_id}",
            response_model=ResourceGroup,response_model_exclude_none=True
)
def get_resources_by_course(course_id: str):
    """
    Fetches all approved resources for a specific course, grouped by type.
    """
    LOGGER.info(f"Fetching resources for course {course_id}")
    try:
        pipeline = [
            # 1. Match approved resources for this specific course
            {"$match": {"approved": True, "course.code": course_id}},

            # 2. Group by Type first (to bundle the items)
            {
                "$group": {
                    "_id": "$type",
                    "items": {
                        "$push": {
                            "id": {"$toString": "$_id"},
                            "year": "$year",
                            "semester": "$semester",
                            "instructorName": "$instructorName",
                            "quizNumber": "$quizNumber",
                            "filePath": "$filePath",
                            "uploadedAt": "$uploadedAt",
                        }
                    },
                    # Grab course info once so we can use it in the next stage
                    "course": {"$first": "$course"}
                }
            },

            # 3. Group everything into a single document to build the Map
            {
                "$group": {
                    "_id": "$course", # Group by the course object
                    "cat_array": {
                        "$push": {
                            "k": "$_id",   # The type (e.g., 'quiz')
                            "v": "$items"  # The list of entries
                        }
                    }
                }
            },

            # 4. Transform the array into a keyed Dictionary/Map
            {
                "$project": {
                    "_id": 0,
                    "course": "$_id",
                    "resources": {"$arrayToObject": "$cat_array"}
                }
            }
        ]

        results = list(resources_collection.aggregate(pipeline))
        LOGGER.info(f"Fetched {len(results)} resource categories for course {course_id}")
        if not results:
            raise HTTPException(status_code=404, detail="Course not found or no approved resources")
        LOGGER.debug(f"Resource Data: {results[0]}")
        LOGGER.info(f"Ended fetching resources for course {course_id} successfully")

        return results[0]

    except Exception as e:
        LOGGER.error(f"Error fetching resources for course {course_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Internal Server Error")
    

@router.put("/resources/{resource_id}")
def update_resource(resource_id: str, user_id: str, update_data: ResourceUpdate):
    """
    Updates details of a resource. 
    Only the Uploader or an Admin can update.
    """
    if not ObjectId.is_valid(resource_id):
        raise HTTPException(status_code=400, detail="Invalid ID")
        
    try:
        resource = resources_collection.find_one({"_id": ObjectId(resource_id)})
        if not resource:
            raise HTTPException(status_code=404, detail="Resource not found")

        # Check permission: Must be Uploader or Admin
        if resource.get("uploaded_by") != user_id and not is_admin(user_id):
            raise HTTPException(status_code=403, detail="Permission denied")

        data = {k: v for k, v in update_data.model_dump().items() if v is not None}
        
        result = resources_collection.update_one(
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
        resource = resources_collection.find_one({"_id": ObjectId(resource_id)})
        if not resource:
            raise HTTPException(status_code=404, detail="Resource not found")

        # Check permission: Must be Uploader or Admin
        if resource.get("uploaded_by") != user_id and not is_admin(user_id):
            raise HTTPException(status_code=403, detail="Permission denied")

        result = resources_collection.delete_one({"_id": ObjectId(resource_id)})
        
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
#         resources = list(resources_collection.find({"approved": False}).sort("uploaded_at", 1))
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
        resource = resources_collection.find_one({"_id": ObjectId(resource_id)})
        if not resource:
            raise HTTPException(status_code=404, detail="Resource not found")
            
        if resource.get("approved") is True:
            return {"success": False, "message": "Resource is already approved"}

        result = resources_collection.update_one(
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
        resource = resources_collection.find_one({"_id": ObjectId(resource_id)})
        if not resource:
            raise HTTPException(status_code=404, detail="Resource not found")
            
        if resource.get("approved") is True:
            raise HTTPException(status_code=400, detail="Cannot reject an already approved resource. Use delete.")

        resources_collection.delete_one({"_id": ObjectId(resource_id)})
        LOGGER.info(f"Resource {resource_id} rejected by admin {user_id}")
        return {"success": True, "message": "Resource rejected and removed"}
        
    except HTTPException:
        raise
    except Exception as e:
        LOGGER.error(f"Error rejecting resource: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")
