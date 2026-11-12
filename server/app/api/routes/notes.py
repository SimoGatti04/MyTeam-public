"""Note API routes"""
from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.note import Note
from app.schemas.note import NoteCreate, NoteUpdate, NoteResponse

router = APIRouter()


@router.get("/api/videos/{video_id}/notes", response_model=List[NoteResponse])
async def list_video_notes(
    video_id: str,
    db: Session = Depends(get_db),
):
    """List all notes for a video"""
    # Verifica che il video esista
    from app.models.video import Video
    video = db.query(Video).filter(Video.id == video_id).first()
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")
    
    notes = db.query(Note).filter(Note.video_id == video_id).order_by(Note.created_at.desc()).all()
    return [NoteResponse(**note.__dict__) for note in notes]


@router.get("/api/videos/{video_id}/notes/{note_id}", response_model=NoteResponse)
async def get_note(
    video_id: str,
    note_id: str,
    db: Session = Depends(get_db),
):
    """Get a note by ID"""
    note = db.query(Note).filter(
        Note.id == note_id,
        Note.video_id == video_id
    ).first()
    
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    
    return NoteResponse(**note.__dict__)


@router.post("/api/videos/{video_id}/notes", response_model=NoteResponse, status_code=201)
async def create_note(
    video_id: str,
    note_data: NoteCreate,
    db: Session = Depends(get_db),
):
    """Create a new note for a video"""
    # Verifica che il video esista
    from app.models.video import Video
    video = db.query(Video).filter(Video.id == video_id).first()
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")
    
    note = Note(
        video_id=video_id,
        **note_data.dict()
    )
    db.add(note)
    db.commit()
    db.refresh(note)
    
    return NoteResponse(**note.__dict__)


@router.put("/api/videos/{video_id}/notes/{note_id}", response_model=NoteResponse)
async def update_note(
    video_id: str,
    note_id: str,
    note_data: NoteUpdate,
    db: Session = Depends(get_db),
):
    """Update a note"""
    note = db.query(Note).filter(
        Note.id == note_id,
        Note.video_id == video_id
    ).first()
    
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    
    update_data = note_data.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(note, key, value)
    
    db.commit()
    db.refresh(note)
    
    return NoteResponse(**note.__dict__)


@router.delete("/api/videos/{video_id}/notes/{note_id}", status_code=204)
async def delete_note(
    video_id: str,
    note_id: str,
    db: Session = Depends(get_db),
):
    """Delete a note"""
    note = db.query(Note).filter(
        Note.id == note_id,
        Note.video_id == video_id
    ).first()
    
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    
    db.delete(note)
    db.commit()
    return None

