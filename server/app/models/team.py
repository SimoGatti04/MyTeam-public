"""Team model"""
from sqlalchemy import Column, String, Text, DateTime, UniqueConstraint, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base
import uuid


class Team(Base):
    """Team database model"""
    __tablename__ = "teams"
    
    # Primary key
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # Basic info
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    logo_url = Column(String(500), nullable=True)
    color = Column(String(7), nullable=True)  # Hex color
    
    # Timestamps
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)
    
    # Relationships
    video_teams = relationship("VideoTeam", back_populates="team", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<Team(id={self.id}, name={self.name})>"


class VideoTeam(Base):
    """Video-Team association model"""
    __tablename__ = "video_teams"
    
    # Primary key
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # Foreign keys
    video_id = Column(String, ForeignKey('videos.id'), nullable=False)
    team_id = Column(String, ForeignKey('teams.id'), nullable=False)
    
    # Timestamp
    tagged_at = Column(DateTime, default=func.now(), nullable=False)
    
    # Relationships
    team = relationship("Team", back_populates="video_teams")
    
    # Unique constraint: una squadra può essere taggata una sola volta per video
    __table_args__ = (UniqueConstraint('video_id', 'team_id', name='uq_video_team'),)
    
    def __repr__(self):
        return f"<VideoTeam(video_id={self.video_id}, team_id={self.team_id})>"

