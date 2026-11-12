"""Team Pydantic schemas"""
from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class TeamBase(BaseModel):
    """Base team schema"""
    name: str
    description: Optional[str] = None
    logo_url: Optional[str] = None
    color: Optional[str] = None  # Hex color


class TeamCreate(TeamBase):
    """Schema for creating a team"""
    pass


class TeamUpdate(BaseModel):
    """Schema for updating a team"""
    name: Optional[str] = None
    description: Optional[str] = None
    logo_url: Optional[str] = None
    color: Optional[str] = None


class TeamResponse(TeamBase):
    """Schema for team response"""
    id: str
    created_at: datetime
    updated_at: datetime
    video_count: Optional[int] = 0  # Numero video associati (calcolato)
    
    class Config:
        from_attributes = True


class VideoTeamCreate(BaseModel):
    """Schema for associating a team with a video"""
    team_id: str


class VideoTeamResponse(BaseModel):
    """Schema for video-team association response"""
    id: str
    video_id: str
    team_id: str
    team: Optional[TeamResponse] = None  # Team details
    tagged_at: datetime
    
    class Config:
        from_attributes = True

