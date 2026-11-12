"""Upload queue model"""
from sqlalchemy import Column, String, Integer, BigInteger, Float, DateTime, Text
from sqlalchemy.sql import func
from app.core.database import Base
import uuid


class UploadQueue(Base):
    """Upload queue database model"""
    __tablename__ = "upload_queue"
    
    # Primary key
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # Video reference (null if not yet created)
    video_id = Column(String, nullable=True)
    
    # File info
    local_filename = Column(String(255), nullable=False)
    remote_filename = Column(String(255), nullable=False)
    file_path = Column(String(500), nullable=False)  # Temporary path during upload
    total_bytes = Column(BigInteger, nullable=False)
    uploaded_bytes = Column(BigInteger, default=0)
    
    # Status
    status = Column(String(20), default="pending")  # pending, uploading, paused, completed, failed, cancelled
    progress = Column(Float, default=0.0)  # 0.0 - 1.0
    
    # Error handling
    error_message = Column(Text, nullable=True)
    
    # Timestamps
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    
    def __repr__(self):
        return f"<UploadQueue(id={self.id}, status={self.status}, progress={self.progress})>"

