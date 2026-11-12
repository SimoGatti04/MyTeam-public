"""Video model"""
from sqlalchemy import Column, String, Integer, BigInteger, Float, DateTime, Text, JSON
from sqlalchemy.sql import func
from app.core.database import Base
import uuid
from datetime import datetime


class Video(Base):
    """Video database model"""
    __tablename__ = "videos"
    
    # Primary key
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # Basic info
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    filename = Column(String(255), nullable=False)
    file_path = Column(String(500), nullable=False)
    
    # File info
    file_size = Column(BigInteger, nullable=False)  # bytes
    file_format = Column(String(10), nullable=False)  # mp4, avi, etc.
    
    # Metadata (extracted from video)
    duration = Column(Integer, nullable=True)  # seconds
    width = Column(Integer, nullable=True)  # Risoluzione video compresso salvato
    height = Column(Integer, nullable=True)  # Risoluzione video compresso salvato
    thumbnail_path = Column(String(500), nullable=True)
    
    # Compression metadata (client-side compression)
    original_resolution_width = Column(Integer, nullable=True)  # Risoluzione originale prima compressione
    original_resolution_height = Column(Integer, nullable=True)
    original_framerate = Column(Float, nullable=True)  # Framerate originale prima compressione
    compressed_framerate = Column(Float, nullable=True)  # Framerate compresso scelto dall'utente
    original_file_size = Column(BigInteger, nullable=True)  # Dimensione originale prima compressione (bytes)
    compression_ratio = Column(Float, nullable=True)  # Risparmio % (0.0-1.0, es: 0.75 = 75% risparmio)
    
    # Future: Transcoding paths (NULL for now - transcoding server-side opzionale)
    transcoded_480p_path = Column(String(500), nullable=True)
    transcoded_720p_path = Column(String(500), nullable=True)
    transcoded_1080p_path = Column(String(500), nullable=True)
    transcoded_1440p_path = Column(String(500), nullable=True)
    transcoded_2160p_path = Column(String(500), nullable=True)
    
    # Status
    status = Column(String(20), default="ready")  # processing, ready, error
    transcoding_status = Column(String(20), default="not_started")  # Future: not_started, processing, completed, error
    
    # Additional metadata (JSON)
    video_metadata = Column(JSON, nullable=True)  # codec, bitrate, etc. (renamed from 'metadata' - SQLAlchemy reserved)
    
    # Error tracking
    metadata_extraction_error = Column(Text, nullable=True)  # JSON error log if metadata extraction fails
    
    # Timestamps
    created_at = Column(DateTime, default=func.now(), nullable=False)  # Data di aggiunta
    recorded_date = Column(DateTime, nullable=True)                    # Data di realizzazione (modificabile)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)
    
    def __repr__(self):
        return f"<Video(id={self.id}, title={self.title}, filename={self.filename})>"

