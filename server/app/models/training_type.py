"""TrainingType model"""
from sqlalchemy import Column, String, Text, DateTime, UniqueConstraint, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base
import uuid


class TrainingType(Base):
    """TrainingType database model"""
    __tablename__ = "training_types"
    
    # Primary key
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # Basic info
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    category = Column(String(100), nullable=True)  # "Riscaldamento", "Esercizio", "Partita"
    color = Column(String(7), nullable=True)        # Hex color
    
    # Timestamps
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)
    
    # Relationships
    video_training_types = relationship("VideoTrainingType", back_populates="training_type", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<TrainingType(id={self.id}, name={self.name})>"


class VideoTrainingType(Base):
    """Video-TrainingType association model"""
    __tablename__ = "video_training_types"
    
    # Primary key
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # Foreign keys
    video_id = Column(String, ForeignKey('videos.id'), nullable=False)
    training_type_id = Column(String, ForeignKey('training_types.id'), nullable=False)
    
    # Timestamp
    tagged_at = Column(DateTime, default=func.now(), nullable=False)
    
    # Relationships
    training_type = relationship("TrainingType", back_populates="video_training_types")
    
    # Unique constraint: un training type può essere taggato una sola volta per video
    __table_args__ = (UniqueConstraint('video_id', 'training_type_id', name='uq_video_training_type'),)
    
    def __repr__(self):
        return f"<VideoTrainingType(video_id={self.video_id}, training_type_id={self.training_type_id})>"

