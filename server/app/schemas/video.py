"""Video Pydantic schemas"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


class VideoBase(BaseModel):
    """Base video schema"""
    title: str
    description: Optional[str] = None
    filename: str
    file_size: int
    file_format: str


class VideoCreate(VideoBase):
    """Schema for creating a video"""
    pass


class VideoResponse(VideoBase):
    """Schema for video response"""
    id: str
    file_path: str
    duration: Optional[int] = None
    width: Optional[int] = None
    height: Optional[int] = None
    thumbnail_path: Optional[str] = None
    status: str
    video_metadata: Optional[dict] = None
    original_resolution_width: Optional[int] = None
    original_resolution_height: Optional[int] = None
    original_framerate: Optional[float] = None
    compressed_framerate: Optional[float] = None
    original_file_size: Optional[int] = None
    compression_ratio: Optional[float] = None
    created_at: datetime
    recorded_date: Optional[datetime] = None  # Data di realizzazione (modificabile)
    updated_at: datetime
    player_ids: Optional[List[str]] = None  # Lista ID giocatori associati
    training_type_ids: Optional[List[str]] = None  # Lista ID training types associati
    team_ids: Optional[List[str]] = None  # Lista ID teams associati
    
    class Config:
        from_attributes = True


class VideoListItem(BaseModel):
    """Schema for video list item (lightweight)"""
    id: str
    title: str
    filename: str
    file_size: int
    duration: Optional[int] = None
    width: Optional[int] = None
    height: Optional[int] = None
    thumbnail_url: Optional[str] = None
    status: str
    created_at: datetime
    
    class Config:
        from_attributes = True


class VideoListResponse(BaseModel):
    """Schema for video list response"""
    items: list[VideoListItem]
    total: int
    page: int
    limit: int

