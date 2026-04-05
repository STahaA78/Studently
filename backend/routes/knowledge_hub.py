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
@router.post("/resources/upload",response_model=GenericResponse)
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
                path_parts.append(f"{meta_dict.get('instructorName', '')}")

        folder_path = os.path.join(*path_parts)
        os.makedirs(folder_path, exist_ok=True)

        _, ext = os.path.splitext(file.filename)
        filename = f"{uuid.uuid4()}{ext}"
        file_path = os.path.join(folder_path, filename)

        # Stream File
        with open(file_path, "wb") as f:
            while chunk := await file.read(1024 * 1024):  # 1 MB chunks
                f.write(chunk)

        meta_dict['file_path'] = file_path
        # ---
        meta_dict['uploaded_at'] = datetime.now(timezone.utc).replace(tzinfo=None)
        meta_dict['uploaded_by'] = user
        meta_dict['approved'] = True  # Trust Policy
        meta_dict['download_count'] = 0
        
        # Convert camelCase to snake_case for database storage
        if 'instructorName' in meta_dict:
            meta_dict['instructor_name'] = meta_dict.pop('instructorName')
        if 'quizNumber' in meta_dict:
            meta_dict['quiz_number'] = meta_dict.pop('quizNumber')
        if 'isSolved' in meta_dict:
            meta_dict['is_solved'] = meta_dict.pop('isSolved')
        
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
                            "instructorName": "$instructor_name",
                            "quizNumber": "$quiz_number",
                            "isSolved": "$is_solved",
                            "gdriveLink": "$gdrive_link",
                            "uploadedAt": "$uploaded_at",
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
                    "resources": { "$arrayToObject": "$cat_list" }
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
        LOGGER.warning(f"Invalid ObjectId format: {resource_id}", extra={"uid": user})
        raise HTTPException(status_code=400, detail="Invalid ID format")
        
    try:
        # Query the resource
        try:
            resource = resources_collection.find_one({"_id": ObjectId(resource_id), "approved": True})
        except Exception as db_error:
            LOGGER.error(f"Database query error: {db_error}", exc_info=True, extra={"uid": user})
            raise HTTPException(status_code=500, detail="Database error while fetching resource")
        
        if not resource:
            LOGGER.warning(f"Resource not found or not approved: {resource_id}", extra={"uid": user})
            raise HTTPException(status_code=404, detail="Resource not found or not approved")

        file_path = resource.get("file_path") or resource.get("filePath")
        LOGGER.debug(f"Resource file path: {file_path}", extra={"uid": user})
        
        if not file_path:
            LOGGER.error(f"Resource has no filePath: {resource_id}", extra={"uid": user})
            raise HTTPException(status_code=400, detail="Resource does not have a file path")
        
        if not os.path.isfile(file_path):
            LOGGER.error(f"File not found on server: {file_path}", extra={"uid": user})
            raise HTTPException(status_code=404, detail=f"File not found on server: {file_path}")

        # Increment download count
        try:
            resources_collection.update_one(
                {"_id": ObjectId(resource_id)},
                {"$inc": {"downloadCount": 1}}
            )
        except Exception as update_error:
            LOGGER.error(f"Failed to update download count: {update_error}", exc_info=True, extra={"uid": user})
            # Don't fail the download if we can't increment the count

        LOGGER.info(f"Resource {resource_id} Downloaded Request Successful", extra={"uid": user})
        return FileResponse(
                path=file_path,
                media_type="application/pdf",
                headers={
                    "Content-Disposition": f'inline; filename="{os.path.basename(file_path)}"',
                    "Accept-Ranges": "bytes",
                },
            )
    except HTTPException:
        raise
    except Exception as e:
        LOGGER.error(f"Unexpected error downloading resource {resource_id}: {e}", exc_info=True, extra={"uid": user})
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}")

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
                            "instructorName": "$instructor_name",
                            "quizNumber": "$quiz_number",
                            "isSolved": "$is_solved",
                            "gdriveLink": "$gdrive_link",
                            "uploadedAt": "$uploaded_at",
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
        if not results:
            LOGGER.info(f"No resources found for course {course_id}", extra={"uid": user})
            return ResourceGroup(course=Course(code=course_id,name=""), resources={}) # Return empty name to same db
        LOGGER.debug(f"Resource Data: {results[0]}", extra={"uid": user})
        LOGGER.info(f"Ended fetching resources for course {course_id} successfully", extra={"uid": user})
        return ResourceGroup.model_validate(results[0])
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