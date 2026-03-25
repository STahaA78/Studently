from fastapi import APIRouter, HTTPException, Header, Response, Depends
from datetime import datetime
from database import config_collection, users_collection
from models.config import *
from typing import List
import logging
from utils.auth import get_current_user

router = APIRouter()
LOGGER = logging.getLogger(__name__)
# 3. Define your custom format (expects a 'uid' variable)
formatter = logging.Formatter(
        "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    )
if not LOGGER.handlers:
    import sys
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(formatter)
    LOGGER.addHandler(handler)
    LOGGER.setLevel(logging.DEBUG)
########################
# Config General
########################
@router.get("", response_model=Config)
def get_config(if_modified_since: str = Header()):
    """
    Pollable app configuration endpoint.
    Clients can pass `If-Modified-Since` header to get 304 if unchanged.
    """
    LOGGER.info("Fetching app configuration from the database.")    
    app_config = config_collection.find_one({}, {"_id": 0})
    if not app_config:
        LOGGER.warning("No app configuration found in the database.")
        raise HTTPException(status_code=404, detail="App configuration not found")
    updated_at = app_config.get("updated_at")
    if updated_at and if_modified_since:
        # Parse client header
        try:
            client_time = datetime.fromisoformat(if_modified_since)
            server_time = datetime.fromisoformat(updated_at)
        except ValueError as e:
            LOGGER.error(f"Failed to parse If-Modified-Since header: {if_modified_since}")
            LOGGER.info("Returning full config due to header parsing error.")
            return app_config
        if client_time and server_time <= client_time:
            # Config hasn't changed
            LOGGER.info("App config not modified since client timestamp. Returning 304.")
            return Response(status_code=304)
    LOGGER.info("App configuration retrieved successfully.")
    return app_config

########################
# Interests
########################
@router.get("/interests", response_model=List[InterestCategory])
def get_interests():
    LOGGER.info("Fetching all interests from the database.")
    app_config = config_collection.find_one({}, {"_id": 0})
    if not app_config:
        LOGGER.warning("No app configuration found in the database.")
        raise HTTPException(status_code=404, detail="App configuration not found")
    interests = app_config.get("interests", [])
    LOGGER.info(f"Retrieved {len(interests)} interests.")
    return interests

@router.post("/interests", status_code=201)
def add_interest_to_category(interest_category: str, interest: Interest,  USER : dict = Depends(get_current_user)):
    LOGGER.info("Adding interest category to the database.")
    user = users_collection.find_one({"_id": USER})
    if not user:
        LOGGER.warning(f"User with UID {USER} not found in the database.")
        raise HTTPException(status_code=404, detail="User not found")
    if not user.get("isAdmin"):
        LOGGER.warning(f"User with UID {USER} does not have admin privileges.")
        raise HTTPException(status_code=403, detail="Admin privileges required")

    result = config_collection.update_one(
        {"interests.category": interest_category},
        {
            "$addToSet": {"interests.$.data": interest.model_dump()}
        }
    )
    if result.matched_count == 0:
        LOGGER.warning("No app configuration found to update.")
        raise HTTPException(status_code=404, detail="App configuration not found")
    LOGGER.info("Interest category added successfully.")
    return Response(status_code=201)

@router.delete("/interests", status_code=204)
def delete_interest_from_category(interest_category: str, interest_name: str, USER : dict = Depends(get_current_user)):
    LOGGER.info("Deleting interest category from the database.")
    user = users_collection.find_one({"_id": USER})
    if not user:
        LOGGER.warning(f"User with UID {USER} not found in the database.")
        raise HTTPException(status_code=404, detail="User not found")
    if not user.get("isAdmin"):
        LOGGER.warning(f"User with UID {USER} does not have admin privileges.")
        raise HTTPException(status_code=403, detail="Admin privileges required")

    result = config_collection.update_one(
        {"interests.category": interest_category},
        {
            "$pull": {"interests.$.data": {"name": interest_name}}
        }
    )
    if result.matched_count == 0:
        LOGGER.warning("No app configuration found to update.")
        raise HTTPException(status_code=404, detail="App configuration not found")
    LOGGER.info("Interest category deleted successfully.")
    return Response(status_code=204)

########################
# Departments
########################
@router.get("/departments", response_model=List[Department])
def get_departments():
    LOGGER.info("Fetching all departments from the database.")
    app_config = config_collection.find_one({}, {"_id": 0})
    if not app_config:
        LOGGER.warning("No app configuration found in the database.")
        raise HTTPException(status_code=404, detail="App configuration not found")
    departments = app_config.get("departments", [])
    LOGGER.info(f"Retrieved {len(departments)} departments.")
    return departments

@router.post("/departments", status_code=201)
def add_department(department: Department, USER : dict = Depends(get_current_user)):
    LOGGER.info("Adding department to the database.")
    user = users_collection.find_one({"_id": USER})
    if not user:
        LOGGER.warning(f"User with UID {USER} not found in the database.")
        raise HTTPException(status_code=404, detail="User not found")
    if not user.get("isAdmin"):
        LOGGER.warning(f"User with UID {USER} does not have admin privileges.")
        raise HTTPException(status_code=403, detail="Admin privileges required")
    result = config_collection.update_one({}, {"$addToSet": {"departments": department.model_dump()}})
    if result.matched_count == 0:
        LOGGER.warning("No app configuration found to update.")
        raise HTTPException(status_code=404, detail="App configuration not found")
    LOGGER.info("Department added successfully.")
    return Response(status_code=201)

@router.delete("/departments", status_code=204)
def delete_departments(name: str, USER : dict = Depends(get_current_user)):
    LOGGER.info("Deleting department from the database.")
    user = users_collection.find_one({"_id": USER})
    if not user:
        LOGGER.warning(f"User with UID {USER} not found in the database.")
        raise HTTPException(status_code=404, detail="User not found")
    if not user.get("isAdmin"):
        LOGGER.warning(f"User with UID {USER} does not have admin privileges.")
        raise HTTPException(status_code=403, detail="Admin privileges required")
    result = config_collection.update_one({"departments.name": name}, {"$pull": {"departments": {"name": name}}})
    if result.matched_count == 0:
        LOGGER.warning("No app configuration found to update.")
        raise HTTPException(status_code=404, detail="App configuration not found")
    LOGGER.info("Department deleted successfully.")
    return Response(status_code=204)

###################
# Batch Range 
########################
@router.get("/batch-range", response_model=BatchRange)
def get_batch_range():
    LOGGER.info("Fetching batch range from the database.")
    app_config = config_collection.find_one({}, {"_id": 0})
    if not app_config:
        LOGGER.warning("No app configuration found in the database.")
        raise HTTPException(status_code=404, detail="App configuration not found")
    batch_range = app_config.get("batch_range")
    LOGGER.info(f"Batch range retrieved: {batch_range}")
    return batch_range

@router.patch("/batch-range", status_code=204)
def update_batch_range(batch_range: BatchRange, USER : dict = Depends(get_current_user)):
    LOGGER.info("Updating batch range in the database.")
    user = users_collection.find_one({"_id": USER})
    if not user:
        LOGGER.warning(f"User with UID {USER} not found in the database.")
        raise HTTPException(status_code=404, detail="User not found")
    if not user.get("isAdmin"):
        LOGGER.warning(f"User with UID {USER} does not have admin privileges.")
        raise HTTPException(status_code=403, detail="Admin privileges required")
    result = config_collection.update_one({}, {"$set": {"batch_range": batch_range.model_dump(), "updated_at": datetime.now(datetime.timezone.utc).isoformat()}})
    if result.matched_count == 0:
        LOGGER.warning("No app configuration found to update.")
        raise HTTPException(status_code=404, detail="App configuration not found")
    LOGGER.info("Batch range updated successfully.")
    return Response(status_code=204)
#######################
# Current Term
########################
@router.get("/current-term", response_model=CurrentTerm)
def get_current_term():
    LOGGER.info("Fetching current term from the database.")
    app_config = config_collection.find_one({}, {"_id": 0})
    if not app_config:
        LOGGER.warning("No app configuration found in the database.")
        raise HTTPException(status_code=404, detail="App configuration not found")
    current_term = app_config.get("current_term")
    LOGGER.info(f"Current term retrieved: {current_term}")
    return current_term
@router.patch("/current-term", status_code=204)
def update_current_term(current_term: CurrentTerm, USER : dict = Depends(get_current_user)):
    LOGGER.info("Updating current term in the database.")
    user = users_collection.find_one({"_id": USER})
    if not user:
        LOGGER.warning(f"User with UID {USER} not found in the database.")
        raise HTTPException(status_code=404, detail="User not found")
    if not user.get("isAdmin"):
        LOGGER.warning(f"User with UID {USER} does not have admin privileges.")
        raise HTTPException(status_code=403, detail="Admin privileges required")
    result = config_collection.update_one({}, {"$set": {"current_term": current_term.model_dump(), "updated_at": datetime.now(datetime.timezone.utc).isoformat()}})
    if result.matched_count == 0:
        LOGGER.warning("No app configuration found to update.")
        raise HTTPException(status_code=404, detail="App configuration not found")
    LOGGER.info("Current term updated successfully.")
    return Response(status_code=204)