from pydantic import BaseModel, Field, model_validator
from datetime import datetime
from typing import List, Optional, Literal, Dict

# Course
class Course(BaseModel):
    code: str
    name: str

# Request Models

# Model for resource metadata
class ResourceInMetadata(BaseModel):
    course: Course
    instructorName: Optional[str] = None
    type: Literal['final', 'midterm', 'quiz', 'book']
    quizNumber: Optional[int] = None  # Only for quizzes
    year: int = Field(..., ge=2000, le=datetime.now().year)
    semester: Literal['Fall', 'Spring', 'Summer']
    isSolved: Optional[bool] = None  

    @model_validator(mode='after')
    def validation(self):
        quizNumber = self.quizNumber
        instructorName = self.instructorName
        if self.type == 'quiz':
            if instructorName is None:
                raise ValueError('Instructor name must be provided for quiz resources')    
            if  (quizNumber is None or quizNumber <= 0):
                raise ValueError('Quiz number must be provided and greater than 0 for quiz resources')
        return self

# NEW: Model for updating a resource
class ResourceUpdate(BaseModel):
    course: Optional[Course] = None
    fileType: Optional[str] = None
    fileName: Optional[str] = None
    tags: Optional[List[str]] = None


# Response Models
class ResourceItem(BaseModel):
    id: str
    year: int = Field(..., ge=2000, le=datetime.now().year)
    semester: Literal['Fall', 'Spring', 'Summer']
    instructorName: Optional[str] = None
    quizNumber: Optional[int] = None
    isSolved: Optional[bool] = None
    filePath: str
    uploadedAt: datetime

# List all Resources
class ResourceGroup(BaseModel):
    course: Course
    resources: Optional[Dict[Literal['final', 'midterm', 'quiz', 'book'], List[ResourceItem]]] = None

# Upload Response
class GenericResponse(BaseModel):
    success: bool
    message: Optional[str] = None
