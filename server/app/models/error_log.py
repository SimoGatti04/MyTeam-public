"""Error log model"""
from sqlalchemy import Column, String, DateTime, JSON, Text
from sqlalchemy.sql import func
from app.core.database import Base
import uuid


class ErrorLog(Base):
    """Error log database model for debugging"""
    __tablename__ = "error_logs"
    
    # Primary key
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # Video reference (nullable if error before video creation)
    video_id = Column(String, nullable=True)
    
    # Operation type
    operation = Column(String(50), nullable=False)  # "upload", "compression", "metadata_extraction", "thumbnail_generation"
    
    # Error data (full error log JSON)
    error_data = Column(JSON, nullable=False)
    
    # Timestamps
    created_at = Column(DateTime, default=func.now(), nullable=False)
    
    def __repr__(self):
        return f"<ErrorLog(id={self.id}, operation={self.operation}, video_id={self.video_id})>"

