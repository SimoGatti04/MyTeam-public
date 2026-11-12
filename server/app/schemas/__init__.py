"""Pydantic schemas for API validation"""
from .video import VideoBase, VideoCreate, VideoResponse, VideoListItem, VideoListResponse
from .player import (
    PlayerBase, PlayerCreate, PlayerUpdate, PlayerResponse,
    VideoPlayerCreate, VideoPlayerResponse
)
from .training_type import (
    TrainingTypeBase, TrainingTypeCreate, TrainingTypeUpdate, TrainingTypeResponse,
    VideoTrainingTypeCreate, VideoTrainingTypeResponse
)
from .team import (
    TeamBase, TeamCreate, TeamUpdate, TeamResponse,
    VideoTeamCreate, VideoTeamResponse
)
from .note import NoteBase, NoteCreate, NoteUpdate, NoteResponse

__all__ = [
    # Video
    "VideoBase",
    "VideoCreate",
    "VideoResponse",
    "VideoListItem",
    "VideoListResponse",
    # Player
    "PlayerBase",
    "PlayerCreate",
    "PlayerUpdate",
    "PlayerResponse",
    "VideoPlayerCreate",
    "VideoPlayerResponse",
    # TrainingType
    "TrainingTypeBase",
    "TrainingTypeCreate",
    "TrainingTypeUpdate",
    "TrainingTypeResponse",
    "VideoTrainingTypeCreate",
    "VideoTrainingTypeResponse",
    # Team
    "TeamBase",
    "TeamCreate",
    "TeamUpdate",
    "TeamResponse",
    "VideoTeamCreate",
    "VideoTeamResponse",
    # Note
    "NoteBase",
    "NoteCreate",
    "NoteUpdate",
    "NoteResponse",
]

