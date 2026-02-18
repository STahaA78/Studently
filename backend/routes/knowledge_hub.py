import json
import sys
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from fastapi.responses import FileResponse
from utils.auth import get_current_user
from database import users_collection, courses_collection, resources_collection
from models.knowledge_hub import *
from bson import ObjectId
from datetime import datetime, timezone
from typing import List
import logging
import os
import uuid
from jsonschema import ValidationError

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
###################################
# Course 
###################################

@router.post("/courses/add", response_model=GenericResponse)
def add_course(course: List[Course], user: dict = Depends(get_current_user)):
    """
    Adds a new course to the system. Only Admins can add courses.
    """
    LOGGER.info(f"Course Add Started", extra={"uid": user})
    if not is_admin(user):
        LOGGER.warning(f"Unauthorized course addition attempt by user {user}")
        raise HTTPException(status_code=403, detail="Only admins can add courses")
    try:
        # Check if course code already exists
        for c in course:
            if courses_collection.find_one({"code": c.code}):
                raise HTTPException(status_code=400, detail=f"Course code {c.code} already exists")

        result = courses_collection.insert_many([c.model_dump() for c in course])
        LOGGER.info(f"Course(s) added successfully Count: {len(result.inserted_ids)}", extra={"uid": user})

        return GenericResponse(success=True, message="Course(s) added successfully")
    except Exception as e:
        LOGGER.error(f"Course Add Failed. Error: {e}", exc_info=True, extra={"uid": user})
        raise HTTPException(status_code=500, detail="Internal Server Error")

@router.delete("/courses/{course_code}", response_model=GenericResponse)
def delete_course(course_code: str, user: dict = Depends(get_current_user)):
    """
    Deletes a course by its code. Only Admins can delete courses.
    """
    LOGGER.info(f"Delete Course Started for{course_code} by user {user}", extra={"uid": user})
    if not is_admin(user):
        LOGGER.warning(f"Unauthorized course deletion attempt by user {user}", extra={"uid": user})
        raise HTTPException(status_code=403, detail="Only admins can delete courses")
    try:
        result = courses_collection.delete_one({"code": course_code})
        if result.deleted_count == 0:
            raise HTTPException(status_code=404, detail="Course not found")
        LOGGER.info(f"Delete Course Ended successfully for code {course_code} by user {user}", extra={"uid": user})
        return GenericResponse(success=True, message="Course deleted successfully")
    except Exception as e:
        LOGGER.error(f"Course Delete Failed. Error: {e}", exc_info=True, extra={"uid": user})
        raise HTTPException(status_code=500, detail="Internal Server Error")

@router.get("/courses", response_model=List[Course])
def get_all_courses(user: dict = Depends(get_current_user)):
    """
    Returns a list of all courses in the system, sorted by name.
    """

    LOGGER.info(f"Get All Courses Initiated ", extra={"uid": user})
    try:
        results = list(courses_collection.find({},{"_id": 0}).sort("name", 1))
        LOGGER.info(f"Get All Courses Ended Successfully. {len(results)} courses", extra={"uid": user})
        return results
    except Exception as e:
        LOGGER.info("Get All Courses Failed", extra={"uid": user})
        LOGGER.error(f"Error fetching courses: {e}", extra={"uid": user}, exc_info=True)
        raise HTTPException(status_code=500, detail="Internal Server Error")

##########################
# Resource
###################################
@router.post("/upload",response_model=GenericResponse)
async def upload_resource(
    metadata: str = Form(...),
    file: UploadFile = File(...),
    user: dict = Depends(get_current_user)
):
    """
    Uploads a resource to the Knowledge Hub.
    """
    LOGGER.info(f"Resource Upload Initiated by user {user}", extra={"uid": user})
    try:
        meta_model = ResourceInMetadata.model_validate_json(metadata)
    except ValidationError as ve:
        LOGGER.warning(f"Resource Upload Failed. Validation error: {ve.errors()}", extra={"uid": user})
        raise HTTPException(status_code=422, detail=ve.errors())
    except json.JSONDecodeError:
        LOGGER.warning(f"Resource Upload Failed. Invalid JSON in metadata", extra={"uid": user})
        raise HTTPException(status_code=400, detail="Invalid JSON in meta")
    except Exception as e:
        LOGGER.error(f"Resource Upload Failed. Error parsing metadata: {e}", exc_info=True, extra={"uid": user})
        raise HTTPException(status_code=500, detail="Internal Server Error")
    meta_dict = meta_model.model_dump(exclude_none=True, exclude_unset=True)

    LOGGER.debug(f"Upload Metadata: {meta_dict}", extra={"uid": user})
    try:
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

        LOGGER.info(f"Resource Upload Ended successfully: {result.inserted_id}", extra={"uid": user})
        return GenericResponse(
            success=True, message="Upload Successful"
        )
    except Exception as e:
        LOGGER.error(f"Resource Upload Failed. Error uploading resource: {e}", exc_info=True, extra={"uid": user})
        raise HTTPException(status_code=500, detail="Internal Server Error")


@router.get("/resources", response_model=List[ResourceGroup])
def get_all_resources(user: dict = Depends(get_current_user)):
    """
    Fetches all approved resources grouped by course.
    """
    LOGGER.info("Fetching All Approved resources", extra={"uid": user})
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
        LOGGER.debug(f"Resource Data: {results}", extra={"uid": user})
        LOGGER.info(f"Ended fetching all resources successfully.Fetched {len(results)} resource groups", extra={"uid": user})
        return results

    except Exception as e:
        LOGGER.error(f"Error fetching resources: {e}", exc_info=True, extra={"uid": user})
        raise HTTPException(status_code=500, detail="Internal Server Error")
    

@router.get("/resources/{resource_id}/download")
def download_resource(resource_id: str, user: dict = Depends(get_current_user)):
    """
    Endpoint to download a resource file by its ID.
    Increments the download count on each successful download.
    """
    LOGGER.info(f"Download request for resource {resource_id} initiated", extra={"uid": user})

    if not ObjectId.is_valid(resource_id):
        raise HTTPException(status_code=400, detail="Invalid ID")
        
    try:
        resource = resources_collection.find_one({"_id": ObjectId(resource_id), "approved": True})
        if not resource:
            raise HTTPException(status_code=404, detail="Resource not found")

        file_path = resource.get("filePath")
        if not file_path or not os.path.isfile(file_path):
            raise HTTPException(status_code=404, detail="File not found on server")

        # Increment download count
        resources_collection.update_one(
            {"_id": ObjectId(resource_id)},
            {"$inc": {"downloadCount": 1}}
        )

        LOGGER.info(f"Resource {resource_id} Downloaded Request Successfull", extra={"uid": user})
        return FileResponse(
                path=file_path,
                media_type="application/pdf",   # IMPORTANT
                headers={
                    "Content-Disposition": f'inline; filename="{os.path.basename(file_path)}"',
                    "Accept-Ranges": "bytes",
                },
            )
    except Exception as e:
        LOGGER.error(f"Error downloading resource: {e}", extra={"uid": user})
        raise HTTPException(status_code=500, detail="Internal Server Error")

@router.get("/resources/{course_id}",
            response_model=ResourceGroup,response_model_exclude_none=True
)
def get_resources_by_course(course_id: str, user: dict = Depends(get_current_user)):
    """
    Fetches all approved resources for a specific course, grouped by type.
    """
    LOGGER.info(f"Fetching resources for course {course_id}", extra={"uid": user})
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
        
        LOGGER.debug(f"Resource Data: {results[0]}")
        if not results:
            LOGGER.info(f"No resources found for course {course_id}", extra={"uid": user})
            raise HTTPException(status_code=404, detail="Course not found or no approved resources")
        LOGGER.info(f"Ended fetching resources for course {course_id} successfully", extra={"uid": user})
        return results[0]
    except Exception as e:
        LOGGER.error(f"Error fetching resources for course {course_id}: {e}", exc_info=True, extra={"uid": user})
        raise HTTPException(status_code=500, detail="Internal Server Error")

@router.delete("/resource/{resource_id}")
def delete_resource(resource_id: str, user: dict = Depends(get_current_user)):
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
        if resource.get("uploaded_by") != user and not is_admin(user):
            raise HTTPException(status_code=403, detail="Permission denied")

        result = resources_collection.delete_one({"_id": ObjectId(resource_id)})
        
        LOGGER.info(f"Resource {resource_id} deleted by {user}", extra={"uid": user})
        return {"success": True, "message": "Resource deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        LOGGER.error(f"Error deleting resource: {e}", extra={"uid": user})
        raise HTTPException(status_code=500, detail="Internal Server Error")