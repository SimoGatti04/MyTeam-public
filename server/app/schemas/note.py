"""Note Pydantic schemas"""
from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class NoteBase(BaseModel):
    """Base note schema"""
    content: str
    timestamp: Optional[int] = None  # Secondi nel video (opzionale)
    is_private: bool = True


class NoteCreate(NoteBase):
    """Schema for creating a note"""
    pass


class NoteUpdate(BaseModel):
    """Schema for updating a note"""
    content: Optional[str] = None
    timestamp: Optional[int] = None
    is_private: Optional[bool] = None


class NoteResponse(NoteBase):
    """Schema for note response"""
    id: str
    video_id: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

