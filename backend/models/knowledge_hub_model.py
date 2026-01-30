from pydantic import BaseModel, Field, model_validator
from datetime import datetime
from typing import List, Optional, Literal

# Request Models

# Model for resource metadata
class ResourceInMetadata(BaseModel):
    uploaded_by: str
    course_code: str
    course_name: str
    instructor_name: Optional[str] = None
    resource_type: Literal['final', 'midterm', 'quiz', 'book']
    quiz_number: Optional[int] = None  # Only for quizzes
    year: int = Field(..., ge=2000, le=datetime.now().year)
    semester: Literal['Fall', 'Spring', 'Summer']

    @model_validator(mode='after')
    def validation(self):
        quiz_number = self.quiz_number
        instructor_name = self.instructor_name
        if self.resource_type == 'quiz':
            if instructor_name is None:
                raise ValueError('Instructor name must be provided for quiz resources')    
            if  (quiz_number is None or quiz_number <= 0):
                raise ValueError('Quiz number must be provided and greater than 0 for quiz resources')
        return self
    
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


# Response Models
class ResourceOutMetadata(BaseModel):
    id: str
    year: int = Field(..., ge=2000, le=datetime.now().year)
    semester: Literal['Fall', 'Spring', 'Summer']
    resource_type: Literal['final', 'midterm', 'quiz', 'book']
    instructor_name: Optional[str] = None
    quiz_number: Optional[int] = None
    file_path: str
    uploaded_at: datetime
# List all Resources
class ResourceGroup(BaseModel):
    course_code: str
    course_name: str
    resources: List[ResourceOutMetadata]

# Course
class CourseMetadata(BaseModel):
    course_code: str
    course_name: str

# Upload Response
class UploadResponse(BaseModel):
    message: str
    resource_id: str