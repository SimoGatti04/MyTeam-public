"""TrainingType API routes"""
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.core.database import get_db
from app.models.training_type import TrainingType, VideoTrainingType
from app.schemas.training_type import (
    TrainingTypeCreate, TrainingTypeUpdate, TrainingTypeResponse,
    VideoTrainingTypeCreate, VideoTrainingTypeResponse
)

router = APIRouter()


@router.get("/api/training-types", response_model=List[TrainingTypeResponse])
async def list_training_types(
    search: Optional[str] = Query(None, description="Search by name"),
    category: Optional[str] = Query(None, description="Filter by category"),
    db: Session = Depends(get_db),
):
    """List all training types with optional search and category filter"""
    query = db.query(TrainingType)
    
    if search:
        search_pattern = f"%{search}%"
        query = query.filter(TrainingType.name.ilike(search_pattern))
    
    if category:
        query = query.filter(TrainingType.category == category)
    
    training_types = query.order_by(TrainingType.name).all()
    
    # Calcola video_count per ogni training type
    result = []
    for training_type in training_types:
        video_count = db.query(func.count(VideoTrainingType.id)).filter(
            VideoTrainingType.training_type_id == training_type.id
        ).scalar() or 0
        
        training_type_dict = {
            "id": training_type.id,
            "name": training_type.name,
            "description": training_type.description,
            "category": training_type.category,
            "color": training_type.color,
            "created_at": training_type.created_at,
            "updated_at": training_type.updated_at,
            "video_count": video_count
        }
        result.append(TrainingTypeResponse(**training_type_dict))
    
    return result


@router.get("/api/training-types/{training_type_id}", response_model=TrainingTypeResponse)
async def get_training_type(
    training_type_id: str,
    db: Session = Depends(get_db),
):
    """Get training type by ID"""
    training_type = db.query(TrainingType).filter(TrainingType.id == training_type_id).first()
    if not training_type:
        raise HTTPException(status_code=404, detail="Training type not found")
    
    video_count = db.query(func.count(VideoTrainingType.id)).filter(
        VideoTrainingType.training_type_id == training_type.id
    ).scalar() or 0
    
    training_type_dict = {
        "id": training_type.id,
        "name": training_type.name,
        "description": training_type.description,
        "category": training_type.category,
        "color": training_type.color,
        "created_at": training_type.created_at,
        "updated_at": training_type.updated_at,
        "video_count": video_count
    }
    return TrainingTypeResponse(**training_type_dict)


@router.post("/api/training-types", response_model=TrainingTypeResponse, status_code=201)
async def create_training_type(
    training_type_data: TrainingTypeCreate,
    db: Session = Depends(get_db),
):
    """Create a new training type"""
    training_type = TrainingType(**training_type_data.dict())
    db.add(training_type)
    db.commit()
    db.refresh(training_type)
    
    training_type_dict = {
        "id": training_type.id,
        "name": training_type.name,
        "description": training_type.description,
        "category": training_type.category,
        "color": training_type.color,
        "created_at": training_type.created_at,
        "updated_at": training_type.updated_at,
        "video_count": 0
    }
    return TrainingTypeResponse(**training_type_dict)


@router.put("/api/training-types/{training_type_id}", response_model=TrainingTypeResponse)
async def update_training_type(
    training_type_id: str,
    training_type_data: TrainingTypeUpdate,
    db: Session = Depends(get_db),
):
    """Update a training type"""
    training_type = db.query(TrainingType).filter(TrainingType.id == training_type_id).first()
    if not training_type:
        raise HTTPException(status_code=404, detail="Training type not found")
    
    update_data = training_type_data.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(training_type, key, value)
    
    db.commit()
    db.refresh(training_type)
    
    video_count = db.query(func.count(VideoTrainingType.id)).filter(
        VideoTrainingType.training_type_id == training_type.id
    ).scalar() or 0
    
    training_type_dict = {
        "id": training_type.id,
        "name": training_type.name,
        "description": training_type.description,
        "category": training_type.category,
        "color": training_type.color,
        "created_at": training_type.created_at,
        "updated_at": training_type.updated_at,
        "video_count": video_count
    }
    return TrainingTypeResponse(**training_type_dict)


@router.delete("/api/training-types/{training_type_id}", status_code=204)
async def delete_training_type(
    training_type_id: str,
    db: Session = Depends(get_db),
):
    """Delete a training type"""
    training_type = db.query(TrainingType).filter(TrainingType.id == training_type_id).first()
    if not training_type:
        raise HTTPException(status_code=404, detail="Training type not found")
    
    db.delete(training_type)
    db.commit()
    return None


@router.post("/api/videos/{video_id}/training-types", response_model=VideoTrainingTypeResponse, status_code=201)
async def add_training_type_to_video(
    video_id: str,
    training_type_data: VideoTrainingTypeCreate,
    db: Session = Depends(get_db),
):
    """Add a training type to a video"""
    # Verifica che il video esista
    from app.models.video import Video
    video = db.query(Video).filter(Video.id == video_id).first()
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")
    
    # Verifica che il training type esista
    training_type = db.query(TrainingType).filter(TrainingType.id == training_type_data.training_type_id).first()
    if not training_type:
        raise HTTPException(status_code=404, detail="Training type not found")
    
    # Verifica che non sia già associato (unique constraint)
    existing = db.query(VideoTrainingType).filter(
        VideoTrainingType.video_id == video_id,
        VideoTrainingType.training_type_id == training_type_data.training_type_id
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Training type already associated with this video")
    
    video_training_type = VideoTrainingType(
        video_id=video_id,
        training_type_id=training_type_data.training_type_id
    )
    db.add(video_training_type)
    db.commit()
    db.refresh(video_training_type)
    
    # Costruisci training_type_dict manualmente per evitare problemi con _sa_instance_state
    training_type_dict = {
        "id": training_type.id,
        "name": training_type.name,
        "description": training_type.description,
        "category": training_type.category,
        "color": training_type.color,
        "created_at": training_type.created_at,
        "updated_at": training_type.updated_at,
        "video_count": 0
    }
    
    video_training_type_dict = {
        "id": video_training_type.id,
        "video_id": video_training_type.video_id,
        "training_type_id": video_training_type.training_type_id,
        "tagged_at": video_training_type.tagged_at,
        "training_type": TrainingTypeResponse(**training_type_dict)
    }
    return VideoTrainingTypeResponse(**video_training_type_dict)


@router.delete("/api/videos/{video_id}/training-types/{training_type_id}", status_code=204)
async def remove_training_type_from_video(
    video_id: str,
    training_type_id: str,
    db: Session = Depends(get_db),
):
    """Remove a training type from a video"""
    video_training_type = db.query(VideoTrainingType).filter(
        VideoTrainingType.video_id == video_id,
        VideoTrainingType.training_type_id == training_type_id
    ).first()
    
    if not video_training_type:
        raise HTTPException(status_code=404, detail="Training type not associated with this video")
    
    db.delete(video_training_type)
    db.commit()
    return None

