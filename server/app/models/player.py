"""Player model"""
from sqlalchemy import Column, String, Text, DateTime, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base
import uuid


class Player(Base):
    """Player database model"""
    __tablename__ = "players"
    
    # Primary key
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # Basic info
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    photo_url = Column(String(500), nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)
    
    # Relationships
    video_players = relationship("VideoPlayer", back_populates="player", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<Player(id={self.id}, name={self.name})>"


class VideoPlayer(Base):
    """Video-Player association model"""
    __tablename__ = "video_players"
    
    # Primary key
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # Foreign keys
    video_id = Column(String, ForeignKey('videos.id'), nullable=False)
    player_id = Column(String, ForeignKey('players.id'), nullable=False)
    
    # Timestamp
    tagged_at = Column(DateTime, default=func.now(), nullable=False)
    
    # Relationships
    player = relationship("Player", back_populates="video_players")
    
    def __repr__(self):
        return f"<VideoPlayer(video_id={self.video_id}, player_id={self.player_id})>"

