"""Video service for managing video operations"""
import uuid
import os
from datetime import datetime, timezone
from pathlib import Path
from sqlalchemy.orm import Session
from fastapi import UploadFile, HTTPException
from app.models.video import Video
from app.models.player import VideoPlayer
from app.models.training_type import VideoTrainingType
from app.models.team import VideoTeam
from app.models.note import Note
from app.core.storage import save_file_to_disk, check_disk_space
from app.core.config import get_settings
from app.utils.file_validation import validate_file, sanitize_filename

settings = get_settings()


class VideoService:
    """Service for video operations"""
    
    def __init__(self, db: Session):
        self.db = db
    
    def save_video(
        self,
        file: UploadFile,
        title: str,
        original_resolution_width: int = None,
        original_resolution_height: int = None,
        original_framerate: float = None,
        compressed_framerate: float = None,
        original_file_size: int = None,
        recorded_date: str = None,
    ) -> Video:
        """Salva video compresso al server.
        
        Args:
            file: File video compresso
            title: Titolo video
            original_resolution_width: Risoluzione originale width
            original_resolution_height: Risoluzione originale height
            original_framerate: Framerate originale
            compressed_framerate: Framerate compresso
            original_file_size: Dimensione file originale (bytes)
            
        Returns:
            Video model creato (status: "processing")
            
        Raises:
            HTTPException: 400 se validazione fallisce
            HTTPException: 413 se file troppo grande
            HTTPException: 500 se errore salvataggio
        """
        # Sanitizza filename (validazione già fatta nell'endpoint)
        if file.filename:
            file.filename = sanitize_filename(file.filename)
        
        # Genera filename univoco
        video_id = str(uuid.uuid4())
        file_extension = Path(file.filename).suffix if file.filename else '.mp4'
        filename = f"{video_id}{file_extension}"
        file_path = str(Path(settings.VIDEOS_PATH) / filename)
        
        # Check disk space se file > 10GB
        if original_file_size and original_file_size > 10 * 1024 * 1024 * 1024:
            check_disk_space(original_file_size, settings.VIDEOS_PATH)
        
        # Salva file su disco (async, atomic write)
        # Note: save_file_to_disk è async, ma qui dobbiamo chiamarlo correttamente
        # In realtà, l'endpoint chiamerà save_file_to_disk direttamente
        
        # Calcola compression ratio
        compression_ratio = None
        if original_file_size:
            # Assumiamo che file.size sia disponibile dopo il salvataggio
            # Per ora usiamo il Content-Length header se disponibile
            # Il file_size effettivo verrà aggiornato dopo il salvataggio
            # Per ora mettiamo None e lo aggiorneremo dopo
            pass
        
        # Determina file format
        file_format = file_extension.lstrip('.') if file_extension else 'mp4'
        
        # Processa recorded_date se presente (formato YYYY-MM-DD)
        recorded_date_dt = None
        if recorded_date:
            try:
                # Parse YYYY-MM-DD e normalizza a 12:00:00 UTC
                parsed_date = datetime.strptime(recorded_date, '%Y-%m-%d')
                # Crea datetime UTC esplicito
                from datetime import timezone
                recorded_date_dt = datetime(
                    year=parsed_date.year,
                    month=parsed_date.month,
                    day=parsed_date.day,
                    hour=12,
                    minute=0,
                    second=0,
                    microsecond=0,
                    tzinfo=timezone.utc
                )
                print(f"[VideoService] Recorded date parsed: {recorded_date} -> {recorded_date_dt}")
            except ValueError as e:
                # Se il formato non è valido, ignora la data
                print(f"[VideoService] Error parsing recorded_date '{recorded_date}': {e}")
                pass
        else:
            print(f"[VideoService] No recorded_date provided")
        
        # Crea video entry
        video = Video(
            id=video_id,
            title=title or file.filename or "Untitled",
            filename=filename,
            file_path=file_path,
            file_size=0,  # Verrà aggiornato dopo salvataggio
            file_format=file_format,
            original_resolution_width=original_resolution_width,
            original_resolution_height=original_resolution_height,
            original_framerate=original_framerate,
            compressed_framerate=compressed_framerate,
            original_file_size=original_file_size,
            compression_ratio=compression_ratio,
            recorded_date=recorded_date_dt,
            status="processing",
        )
        
        self.db.add(video)
        self.db.commit()
        self.db.refresh(video)
        
        return video
    
    def update_video_file_size(self, video_id: str, file_size: int) -> Video:
        """Aggiorna dimensione file video dopo salvataggio.
        
        Args:
            video_id: ID video
            file_size: Dimensione file in bytes
            
        Returns:
            Video aggiornato
        """
        video = self.db.query(Video).filter(Video.id == video_id).first()
        if not video:
            raise HTTPException(status_code=404, detail="Video not found")
        
        video.file_size = file_size
        
        # Calcola compression ratio se abbiamo original_file_size
        if video.original_file_size:
            video.compression_ratio = 1.0 - (file_size / video.original_file_size)
        
        self.db.commit()
        self.db.refresh(video)
        
        return video
    
    def update_video_metadata(
        self,
        video_id: str,
        duration: int = None,
        width: int = None,
        height: int = None,
        video_metadata: dict = None,
    ) -> Video:
        """Aggiorna metadata video dopo estrazione.
        
        Args:
            video_id: ID video
            duration: Durata in secondi
            width: Larghezza video
            height: Altezza video
            video_metadata: Metadata aggiuntivi (JSON)
            
        Returns:
            Video aggiornato
        """
        video = self.db.query(Video).filter(Video.id == video_id).first()
        if not video:
            raise HTTPException(status_code=404, detail="Video not found")
        
        if duration is not None:
            video.duration = duration
        if width is not None:
            video.width = width
        if height is not None:
            video.height = height
        if video_metadata is not None:
            video.video_metadata = video_metadata
        
        # Aggiorna status a "ready" se metadata estratti con successo
        if video.status == "processing":
            video.status = "ready"
        
        self.db.commit()
        self.db.refresh(video)
        
        return video
    
    def update_video_thumbnail(self, video_id: str, thumbnail_path: str) -> Video:
        """Aggiorna path thumbnail video.
        
        Args:
            video_id: ID video
            thumbnail_path: Path thumbnail
            
        Returns:
            Video aggiornato
        """
        video = self.db.query(Video).filter(Video.id == video_id).first()
        if not video:
            raise HTTPException(status_code=404, detail="Video not found")
        
        video.thumbnail_path = thumbnail_path
        self.db.commit()
        self.db.refresh(video)
        
        return video
    
    def update_video_metadata_error(self, video_id: str, error_data: dict) -> Video:
        """Aggiorna video con errore metadata extraction.
        
        Args:
            video_id: ID video
            error_data: Dati errore (JSON)
            
        Returns:
            Video aggiornato
        """
        import json
        
        video = self.db.query(Video).filter(Video.id == video_id).first()
        if not video:
            raise HTTPException(status_code=404, detail="Video not found")
        
        video.metadata_extraction_error = json.dumps(error_data)
        video.status = "error"
        
        self.db.commit()
        self.db.refresh(video)
        
        return video
    
    def update_video_status(self, video_id: str, status: str) -> Video:
        """Aggiorna status video.
        
        Args:
            video_id: ID video
            status: Nuovo status ("processing", "ready", "error", "deleted")
            
        Returns:
            Video aggiornato
        """
        video = self.db.query(Video).filter(Video.id == video_id).first()
        if not video:
            raise HTTPException(status_code=404, detail="Video not found")
        
        video.status = status
        self.db.commit()
        self.db.refresh(video)
        
        return video
    
    def update_video_title(self, video_id: str, title: str) -> Video:
        """Aggiorna titolo video.
        
        Args:
            video_id: ID video
            title: Nuovo titolo (max 255 caratteri)
            
        Returns:
            Video aggiornato
            
        Raises:
            HTTPException: 404 se video non trovato
            HTTPException: 400 se titolo invalido (vuoto o troppo lungo)
        """
        # Validazione titolo
        if not title or not title.strip():
            raise HTTPException(status_code=400, detail="Title cannot be empty")
        
        if len(title) > 255:
            raise HTTPException(status_code=400, detail="Title too long (max 255 characters)")
        
        video = self.db.query(Video).filter(Video.id == video_id).first()
        if not video:
            raise HTTPException(status_code=404, detail="Video not found")
        
        # Aggiorna titolo
        video.title = title.strip()
        self.db.commit()
        self.db.refresh(video)
        
        return video
    
    def delete_video(self, video_id: str) -> None:
        """Elimina video dal server (file, thumbnail, associazioni, record DB).
        
        Args:
            video_id: ID video da eliminare
            
        Raises:
            HTTPException: 404 se video non trovato
            HTTPException: 500 se errore durante eliminazione
        """
        video = self.db.query(Video).filter(Video.id == video_id).first()
        if not video:
            raise HTTPException(status_code=404, detail="Video not found")
        
        try:
            # 1. Elimina tutte le associazioni (cascade delete)
            # VideoPlayer
            self.db.query(VideoPlayer).filter(VideoPlayer.video_id == video_id).delete()
            # VideoTrainingType
            self.db.query(VideoTrainingType).filter(VideoTrainingType.video_id == video_id).delete()
            # VideoTeam
            self.db.query(VideoTeam).filter(VideoTeam.video_id == video_id).delete()
            # Note
            self.db.query(Note).filter(Note.video_id == video_id).delete()
            
            # 2. Elimina file video dal disco
            if video.file_path:
                video_path = Path(video.file_path)
                # Se il path non è assoluto, costruisci relativamente a VIDEOS_PATH
                if not video_path.is_absolute():
                    videos_path = Path(settings.VIDEOS_PATH).resolve()
                    video_path = videos_path / video_path.name
                
                if video_path.exists():
                    try:
                        os.remove(video_path)
                    except OSError as e:
                        # Log errore ma continua (file potrebbe essere già eliminato)
                        print(f"Warning: Could not delete video file {video_path}: {e}")
            
            # 3. Elimina thumbnail se esiste
            if video.thumbnail_path:
                thumbnail_path = Path(video.thumbnail_path)
                # Se il path non è assoluto, costruisci relativamente a THUMBNAILS_PATH
                if not thumbnail_path.is_absolute():
                    thumbnails_path = Path(settings.THUMBNAILS_PATH).resolve()
                    thumbnail_path = thumbnails_path / thumbnail_path.name
                
                if thumbnail_path.exists():
                    try:
                        os.remove(thumbnail_path)
                    except OSError as e:
                        # Log errore ma continua
                        print(f"Warning: Could not delete thumbnail {thumbnail_path}: {e}")
            
            # 4. Elimina record dal database
            self.db.delete(video)
            self.db.commit()
            
        except Exception as e:
            self.db.rollback()
            raise HTTPException(
                status_code=500,
                detail=f"Error deleting video: {str(e)}"
            )
