from pydantic import BaseModel, Field
from datetime import datetime
from typing import List, Literal, Optional

class Department(BaseModel):
    name: str

class Interest(BaseModel):
    name: str
    emoji: str

class InterestCategory(BaseModel):
    category: str
    data: List[Interest]

class BatchRange(BaseModel):
    start: int
    end: int
class BatchRangeUpdate(BaseModel):
    start: Optional[int] = None
    end: Optional[int] = None

class CurrentTerm(BaseModel):
    semester: Literal["Spring", "Summer", "Fall"]
    year: int = Field(..., ge=2000, le=datetime.now().year)
class CurrentTermUpdate(BaseModel):
    semester: Optional[Literal["Spring", "Summer", "Fall"]] = None
    year: Optional[int] = Field(None, ge=2000, le=datetime.now().year)

class Config(BaseModel):
    departments: List[Department]
    interests: List[InterestCategory]
    batch_range: BatchRange
    current_term: CurrentTerm
    updated_at: datetime = Field(..., description="Timestamp of the last update in ISO format")