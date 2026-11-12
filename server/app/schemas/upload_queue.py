"""Upload queue Pydantic schemas"""
from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class UploadQueueResponse(BaseModel):
    """Schema for upload queue status response"""
    id: str
    video_id: Optional[str] = None
    filename: str
    file_size: int
    status: str  # queued, processing, completed, error
    progress: float  # 0.0-1.0
    error_message: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class UploadQueueListResponse(BaseModel):
    """Schema for upload queue list response"""
    items: list[UploadQueueResponse]
    active: int
    queued: int
    completed: int
    error: int

