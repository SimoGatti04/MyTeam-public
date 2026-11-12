"""Player Pydantic schemas"""
from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class PlayerBase(BaseModel):
    """Base player schema"""
    name: str
    description: Optional[str] = None
    photo_url: Optional[str] = None


class PlayerCreate(PlayerBase):
    """Schema for creating a player"""
    pass


class PlayerUpdate(BaseModel):
    """Schema for updating a player"""
    name: Optional[str] = None
    description: Optional[str] = None
    photo_url: Optional[str] = None


class PlayerResponse(PlayerBase):
    """Schema for player response"""
    id: str
    created_at: datetime
    updated_at: datetime
    video_count: Optional[int] = 0  # Numero video associati (calcolato)
    
    class Config:
        from_attributes = True


class VideoPlayerCreate(BaseModel):
    """Schema for associating a player with a video"""
    player_id: str


class VideoPlayerResponse(BaseModel):
    """Schema for video-player association response"""
    id: str
    video_id: str
    player_id: str
    player: Optional[PlayerResponse] = None  # Player details
    tagged_at: datetime
    
    class Config:
        from_attributes = True

