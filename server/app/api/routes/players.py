"""Player API routes"""
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.core.database import get_db
from app.models.player import Player, VideoPlayer
from app.schemas.player import (
    PlayerCreate, PlayerUpdate, PlayerResponse,
    VideoPlayerCreate, VideoPlayerResponse
)

router = APIRouter()


@router.get("/api/players", response_model=List[PlayerResponse])
async def list_players(
    search: Optional[str] = Query(None, description="Search by name"),
    db: Session = Depends(get_db),
):
    """List all players with optional search"""
    query = db.query(Player)
    
    if search:
        search_pattern = f"%{search}%"
        query = query.filter(Player.name.ilike(search_pattern))
    
    players = query.order_by(Player.name).all()
    
    # Calcola video_count per ogni player
    result = []
    for player in players:
        video_count = db.query(func.count(VideoPlayer.id)).filter(
            VideoPlayer.player_id == player.id
        ).scalar() or 0
        
        player_dict = {
            "id": player.id,
            "name": player.name,
            "description": player.description,
            "photo_url": player.photo_url,
            "created_at": player.created_at,
            "updated_at": player.updated_at,
            "video_count": video_count
        }
        result.append(PlayerResponse(**player_dict))
    
    return result


@router.get("/api/players/{player_id}", response_model=PlayerResponse)
async def get_player(
    player_id: str,
    db: Session = Depends(get_db),
):
    """Get player by ID"""
    player = db.query(Player).filter(Player.id == player_id).first()
    if not player:
        raise HTTPException(status_code=404, detail="Player not found")
    
    video_count = db.query(func.count(VideoPlayer.id)).filter(
        VideoPlayer.player_id == player.id
    ).scalar() or 0
    
    player_dict = {
        "id": player.id,
        "name": player.name,
        "description": player.description,
        "photo_url": player.photo_url,
        "created_at": player.created_at,
        "updated_at": player.updated_at,
        "video_count": video_count
    }
    return PlayerResponse(**player_dict)


@router.post("/api/players", response_model=PlayerResponse, status_code=201)
async def create_player(
    player_data: PlayerCreate,
    db: Session = Depends(get_db),
):
    """Create a new player"""
    player = Player(**player_data.dict())
    db.add(player)
    db.commit()
    db.refresh(player)
    
    player_dict = {
        "id": player.id,
        "name": player.name,
        "description": player.description,
        "photo_url": player.photo_url,
        "created_at": player.created_at,
        "updated_at": player.updated_at,
        "video_count": 0
    }
    return PlayerResponse(**player_dict)


@router.put("/api/players/{player_id}", response_model=PlayerResponse)
async def update_player(
    player_id: str,
    player_data: PlayerUpdate,
    db: Session = Depends(get_db),
):
    """Update a player"""
    player = db.query(Player).filter(Player.id == player_id).first()
    if not player:
        raise HTTPException(status_code=404, detail="Player not found")
    
    update_data = player_data.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(player, key, value)
    
    db.commit()
    db.refresh(player)
    
    video_count = db.query(func.count(VideoPlayer.id)).filter(
        VideoPlayer.player_id == player.id
    ).scalar() or 0
    
    player_dict = {
        "id": player.id,
        "name": player.name,
        "description": player.description,
        "photo_url": player.photo_url,
        "created_at": player.created_at,
        "updated_at": player.updated_at,
        "video_count": video_count
    }
    return PlayerResponse(**player_dict)


@router.delete("/api/players/{player_id}", status_code=204)
async def delete_player(
    player_id: str,
    db: Session = Depends(get_db),
):
    """Delete a player"""
    player = db.query(Player).filter(Player.id == player_id).first()
    if not player:
        raise HTTPException(status_code=404, detail="Player not found")
    
    db.delete(player)
    db.commit()
    return None


@router.post("/api/videos/{video_id}/players", response_model=VideoPlayerResponse, status_code=201)
async def add_player_to_video(
    video_id: str,
    player_data: VideoPlayerCreate,
    db: Session = Depends(get_db),
):
    """Add a player to a video"""
    # Verifica che il video esista
    from app.models.video import Video
    video = db.query(Video).filter(Video.id == video_id).first()
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")
    
    # Verifica che il player esista
    player = db.query(Player).filter(Player.id == player_data.player_id).first()
    if not player:
        raise HTTPException(status_code=404, detail="Player not found")
    
    # Verifica che non sia già associato
    existing = db.query(VideoPlayer).filter(
        VideoPlayer.video_id == video_id,
        VideoPlayer.player_id == player_data.player_id
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Player already associated with this video")
    
    video_player = VideoPlayer(
        video_id=video_id,
        player_id=player_data.player_id
    )
    db.add(video_player)
    db.commit()
    db.refresh(video_player)
    
    player_dict = {k: v for k, v in player.__dict__.items() if not k.startswith('_')}
    player_dict["video_count"] = 0
    
    # Rimuovi _sa_instance_state dal dict per evitare errori Pydantic
    # Costruisci player_dict manualmente per evitare problemi con _sa_instance_state
    player_dict = {
        "id": player.id,
        "name": player.name,
        "description": player.description,
        "photo_url": player.photo_url,
        "created_at": player.created_at,
        "updated_at": player.updated_at,
        "video_count": 0
    }
    
    video_player_dict = {
        "id": video_player.id,
        "video_id": video_player.video_id,
        "player_id": video_player.player_id,
        "tagged_at": video_player.tagged_at,
        "player": PlayerResponse(**player_dict)
    }
    return VideoPlayerResponse(**video_player_dict)


@router.delete("/api/videos/{video_id}/players/{player_id}", status_code=204)
async def remove_player_from_video(
    video_id: str,
    player_id: str,
    db: Session = Depends(get_db),
):
    """Remove a player from a video"""
    video_player = db.query(VideoPlayer).filter(
        VideoPlayer.video_id == video_id,
        VideoPlayer.player_id == player_id
    ).first()
    
    if not video_player:
        raise HTTPException(status_code=404, detail="Player not associated with this video")
    
    db.delete(video_player)
    db.commit()
    return None

