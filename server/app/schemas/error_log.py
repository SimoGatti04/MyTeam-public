"""Error log Pydantic schemas"""
from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime


class ErrorLogCreate(BaseModel):
    """Schema for creating error log"""
    video_id: Optional[str] = None
    operation: str  # "upload", "compression", "metadata_extraction", "thumbnail_generation"
    error_data: Dict[str, Any]  # Full error log JSON


class ErrorLogResponse(BaseModel):
    """Schema for error log response"""
    id: str
    video_id: Optional[str] = None
    operation: str
    error_data: Dict[str, Any]
    created_at: datetime
    
    class Config:
        from_attributes = True

