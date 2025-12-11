from pydantic import BaseModel, Field
from datetime import datetime
from typing import List, Optional

class ResourceCreate(BaseModel):
    uploaded_by: str
    course_code: str
    course_name: str
    file_type: str 
    file_name: str
    file_url: str
    tags: List[str] = []

# NEW: Model for updating a resource
class ResourceUpdate(BaseModel):
    course_code: Optional[str] = None
    course_name: Optional[str] = None
    file_type: Optional[str] = None
    file_name: Optional[str] = None
    tags: Optional[List[str]] = None

class ResourceOut(BaseModel):
    id: str = Field(alias="_id")
    uploaded_by: str
    course_code: str
    course_name: str
    file_type: str
    file_name: str
    file_url: str
    tags: List[str] = []
    uploaded_at: datetime
    approved: bool
    download_count: int = 0

    class Config:
        populate_by_name = True

class CourseSummary(BaseModel):
    course_code: str
    course_name: str
    resource_count: int