"""TrainingType Pydantic schemas"""
from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class TrainingTypeBase(BaseModel):
    """Base training type schema"""
    name: str
    description: Optional[str] = None
    category: Optional[str] = None  # "Riscaldamento", "Esercizio", "Partita"
    color: Optional[str] = None  # Hex color


class TrainingTypeCreate(TrainingTypeBase):
    """Schema for creating a training type"""
    pass


class TrainingTypeUpdate(BaseModel):
    """Schema for updating a training type"""
    name: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    color: Optional[str] = None


class TrainingTypeResponse(TrainingTypeBase):
    """Schema for training type response"""
    id: str
    created_at: datetime
    updated_at: datetime
    video_count: Optional[int] = 0  # Numero video associati (calcolato)
    
    class Config:
        from_attributes = True


class VideoTrainingTypeCreate(BaseModel):
    """Schema for associating a training type with a video"""
    training_type_id: str


class VideoTrainingTypeResponse(BaseModel):
    """Schema for video-training type association response"""
    id: str
    video_id: str
    training_type_id: str
    training_type: Optional[TrainingTypeResponse] = None  # TrainingType details
    tagged_at: datetime
    
    class Config:
        from_attributes = True

