"""Team API routes"""
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.core.database import get_db
from app.models.team import Team, VideoTeam
from app.schemas.team import (
    TeamCreate, TeamUpdate, TeamResponse,
    VideoTeamCreate, VideoTeamResponse
)

router = APIRouter()


@router.get("/api/teams", response_model=List[TeamResponse])
async def list_teams(
    search: Optional[str] = Query(None, description="Search by name"),
    db: Session = Depends(get_db),
):
    """List all teams with optional search"""
    query = db.query(Team)
    
    if search:
        search_pattern = f"%{search}%"
        query = query.filter(Team.name.ilike(search_pattern))
    
    teams = query.order_by(Team.name).all()
    
    # Calcola video_count per ogni team
    result = []
    for team in teams:
        video_count = db.query(func.count(VideoTeam.id)).filter(
            VideoTeam.team_id == team.id
        ).scalar() or 0
        
        team_dict = {
            "id": team.id,
            "name": team.name,
            "description": team.description,
            "logo_url": team.logo_url,
            "color": team.color,
            "created_at": team.created_at,
            "updated_at": team.updated_at,
            "video_count": video_count
        }
        result.append(TeamResponse(**team_dict))
    
    return result


@router.get("/api/teams/{team_id}", response_model=TeamResponse)
async def get_team(
    team_id: str,
    db: Session = Depends(get_db),
):
    """Get team by ID"""
    team = db.query(Team).filter(Team.id == team_id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
    
    video_count = db.query(func.count(VideoTeam.id)).filter(
        VideoTeam.team_id == team.id
    ).scalar() or 0
    
    team_dict = {
        "id": team.id,
        "name": team.name,
        "description": team.description,
        "logo_url": team.logo_url,
        "color": team.color,
        "created_at": team.created_at,
        "updated_at": team.updated_at,
        "video_count": video_count
    }
    return TeamResponse(**team_dict)


@router.post("/api/teams", response_model=TeamResponse, status_code=201)
async def create_team(
    team_data: TeamCreate,
    db: Session = Depends(get_db),
):
    """Create a new team"""
    team = Team(**team_data.dict())
    db.add(team)
    db.commit()
    db.refresh(team)
    
    team_dict = {
        "id": team.id,
        "name": team.name,
        "description": team.description,
        "logo_url": team.logo_url,
        "color": team.color,
        "created_at": team.created_at,
        "updated_at": team.updated_at,
        "video_count": 0
    }
    return TeamResponse(**team_dict)


@router.put("/api/teams/{team_id}", response_model=TeamResponse)
async def update_team(
    team_id: str,
    team_data: TeamUpdate,
    db: Session = Depends(get_db),
):
    """Update a team"""
    team = db.query(Team).filter(Team.id == team_id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
    
    update_data = team_data.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(team, key, value)
    
    db.commit()
    db.refresh(team)
    
    video_count = db.query(func.count(VideoTeam.id)).filter(
        VideoTeam.team_id == team.id
    ).scalar() or 0
    
    team_dict = {
        "id": team.id,
        "name": team.name,
        "description": team.description,
        "logo_url": team.logo_url,
        "color": team.color,
        "created_at": team.created_at,
        "updated_at": team.updated_at,
        "video_count": video_count
    }
    return TeamResponse(**team_dict)


@router.delete("/api/teams/{team_id}", status_code=204)
async def delete_team(
    team_id: str,
    db: Session = Depends(get_db),
):
    """Delete a team"""
    team = db.query(Team).filter(Team.id == team_id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
    
    db.delete(team)
    db.commit()
    return None


@router.post("/api/videos/{video_id}/teams", response_model=VideoTeamResponse, status_code=201)
async def add_team_to_video(
    video_id: str,
    team_data: VideoTeamCreate,
    db: Session = Depends(get_db),
):
    """Add a team to a video"""
    # Verifica che il video esista
    from app.models.video import Video
    video = db.query(Video).filter(Video.id == video_id).first()
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")
    
    # Verifica che il team esista
    team = db.query(Team).filter(Team.id == team_data.team_id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
    
    # Verifica che non sia già associato (unique constraint)
    existing = db.query(VideoTeam).filter(
        VideoTeam.video_id == video_id,
        VideoTeam.team_id == team_data.team_id
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Team already associated with this video")
    
    video_team = VideoTeam(
        video_id=video_id,
        team_id=team_data.team_id
    )
    db.add(video_team)
    db.commit()
    db.refresh(video_team)
    
    # Costruisci team_dict manualmente per evitare problemi con _sa_instance_state
    team_dict = {
        "id": team.id,
        "name": team.name,
        "description": team.description,
        "logo_url": team.logo_url,
        "color": team.color,
        "created_at": team.created_at,
        "updated_at": team.updated_at,
        "video_count": 0
    }
    
    video_team_dict = {
        "id": video_team.id,
        "video_id": video_team.video_id,
        "team_id": video_team.team_id,
        "tagged_at": video_team.tagged_at,
        "team": TeamResponse(**team_dict)
    }
    return VideoTeamResponse(**video_team_dict)


@router.delete("/api/videos/{video_id}/teams/{team_id}", status_code=204)
async def remove_team_from_video(
    video_id: str,
    team_id: str,
    db: Session = Depends(get_db),
):
    """Remove a team from a video"""
    video_team = db.query(VideoTeam).filter(
        VideoTeam.video_id == video_id,
        VideoTeam.team_id == team_id
    ).first()
    
    if not video_team:
        raise HTTPException(status_code=404, detail="Team not associated with this video")
    
    db.delete(video_team)
    db.commit()
    return None

