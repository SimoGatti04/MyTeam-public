"""Note model"""
from sqlalchemy import Column, String, Text, Integer, DateTime, Boolean, ForeignKey
from sqlalchemy.sql import func
from app.core.database import Base
import uuid


class Note(Base):
    """Note database model"""
    __tablename__ = "notes"
    
    # Primary key
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # Foreign key
    video_id = Column(String, ForeignKey('videos.id'), nullable=False)
    
    # Content
    content = Column(Text, nullable=False)
    timestamp = Column(Integer, nullable=True)  # Secondi nel video (opzionale)
    
    # Privacy
    is_private = Column(Boolean, default=True, nullable=False)
    
    # Timestamps
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)
    
    def __repr__(self):
        return f"<Note(id={self.id}, video_id={self.video_id}, content_length={len(self.content) if self.content else 0})>"

