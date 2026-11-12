"""Upload queue service for managing upload queue operations"""
from datetime import datetime
from sqlalchemy.orm import Session
from fastapi import HTTPException
from app.models.upload_queue import UploadQueue
from app.core.config import get_settings

settings = get_settings()


class UploadQueueService:
    """Service for upload queue operations"""
    
    def __init__(self, db: Session):
        self.db = db
    
    def create_upload_queue_entry(
        self,
        filename: str,
        file_path: str,
        file_size: int,
    ) -> UploadQueue:
        """Crea entry in upload queue.
        
        Args:
            filename: Nome file originale
            file_path: Path file temporaneo
            file_size: Dimensione file in bytes
            
        Returns:
            UploadQueue entry creata (status: "queued")
        """
        upload_queue = UploadQueue(
            local_filename=filename,
            remote_filename=filename,  # Per ora uguale, cambierà dopo salvataggio
            file_path=file_path,
            total_bytes=file_size,
            uploaded_bytes=0,
            status="queued",
            progress=0.0,
        )
        
        self.db.add(upload_queue)
        self.db.commit()
        self.db.refresh(upload_queue)
        
        return upload_queue
    
    def update_upload_queue_status(
        self,
        upload_id: str,
        status: str,
        video_id: str = None,
        progress: float = None,
        error_message: str = None,
    ) -> UploadQueue:
        """Aggiorna status upload queue.
        
        Args:
            upload_id: ID upload queue
            status: Nuovo status (queued, processing, completed, error)
            video_id: ID video (opzionale)
            progress: Progress 0.0-1.0 (opzionale)
            error_message: Messaggio errore (opzionale)
            
        Returns:
            UploadQueue aggiornata
        """
        upload_queue = self.db.query(UploadQueue).filter(
            UploadQueue.id == upload_id
        ).first()
        
        if not upload_queue:
            raise HTTPException(status_code=404, detail="Upload queue entry not found")
        
        upload_queue.status = status
        
        if video_id is not None:
            upload_queue.video_id = video_id
        
        if progress is not None:
            upload_queue.progress = progress
        
        if error_message is not None:
            upload_queue.error_message = error_message
        
        # Aggiorna timestamps
        if status == "processing" and not upload_queue.started_at:
            upload_queue.started_at = datetime.now()
        
        if status in ["completed", "error"]:
            upload_queue.completed_at = datetime.now()
        
        self.db.commit()
        self.db.refresh(upload_queue)
        
        return upload_queue
    
    def update_upload_progress(
        self,
        upload_id: str,
        uploaded_bytes: int,
    ) -> UploadQueue:
        """Aggiorna progress upload.
        
        Args:
            upload_id: ID upload queue
            uploaded_bytes: Bytes uploadati
            
        Returns:
            UploadQueue aggiornata
        """
        upload_queue = self.db.query(UploadQueue).filter(
            UploadQueue.id == upload_id
        ).first()
        
        if not upload_queue:
            raise HTTPException(status_code=404, detail="Upload queue entry not found")
        
        upload_queue.uploaded_bytes = uploaded_bytes
        upload_queue.progress = uploaded_bytes / upload_queue.total_bytes if upload_queue.total_bytes > 0 else 0.0
        
        self.db.commit()
        self.db.refresh(upload_queue)
        
        return upload_queue
    
    def get_upload_queue_entry(self, upload_id: str) -> UploadQueue:
        """Ottiene entry upload queue.
        
        Args:
            upload_id: ID upload queue
            
        Returns:
            UploadQueue entry
        """
        upload_queue = self.db.query(UploadQueue).filter(
            UploadQueue.id == upload_id
        ).first()
        
        if not upload_queue:
            raise HTTPException(status_code=404, detail="Upload queue entry not found")
        
        return upload_queue
    
    def get_active_uploads_count(self) -> int:
        """Conta upload attivi (status: processing).
        
        Returns:
            Numero upload attivi
        """
        return self.db.query(UploadQueue).filter(
            UploadQueue.status == "processing"
        ).count()
