"""Background tasks for video processing"""
import json
import asyncio
from pathlib import Path
from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.core.config import get_settings
from app.services.video_service import VideoService
from app.services.metadata_service import extract_metadata
from app.services.thumbnail_service import generate_thumbnail
from app.models.error_log import ErrorLog

settings = get_settings()


async def extract_metadata_task(video_id: str) -> None:
    """Background task per estrazione metadata video.
    
    Esegue retry automatico (max 5 tentativi) con exponential backoff.
    Se fallisce, salva errore nel database e nel video.
    
    Args:
        video_id: ID video
    """
    db = SessionLocal()
    try:
        video_service = VideoService(db)
        
        # Ottieni video
        from app.models.video import Video
        video = db.query(Video).filter(Video.id == video_id).first()
        
        if not video:
            return
        
        # Retry logic
        max_retries = settings.MAX_RETRIES_BACKGROUND_TASKS
        retry_count = 0
        last_error = None
        
        while retry_count < max_retries:
            try:
                # Estrai metadata
                metadata = await extract_metadata(video.file_path)
                
                # Aggiorna video con metadata
                video_service.update_video_metadata(
                    video_id=video_id,
                    duration=metadata.get('duration'),
                    width=metadata.get('width'),
                    height=metadata.get('height'),
                    video_metadata={
                        'bitrate': metadata.get('bitrate'),
                        'codec': metadata.get('codec'),
                        'framerate': metadata.get('framerate'),
                        'raw_metadata': metadata.get('raw_metadata'),
                    }
                )
                
                # Successo, esci
                return
                
            except Exception as e:
                retry_count += 1
                last_error = e
                
                # Exponential backoff: 2^retry_count secondi
                if retry_count < max_retries:
                    wait_time = 2 ** retry_count
                    await asyncio.sleep(wait_time)
        
        # Tutti i tentativi falliti
        error_data = {
            'error': str(last_error),
            'retries': retry_count,
            'video_id': video_id,
            'operation': 'metadata_extraction',
        }
        
        # Salva errore nel video
        video_service.update_video_metadata_error(video_id, error_data)
        
        # Salva errore in ErrorLog
        error_log = ErrorLog(
            video_id=video_id,
            operation='metadata_extraction',
            error_data=error_data
        )
        db.add(error_log)
        db.commit()
        
    except Exception as e:
        # Errore critico
        error_log = ErrorLog(
            video_id=video_id,
            operation='metadata_extraction',
            error_data={'error': str(e), 'critical': True}
        )
        db.add(error_log)
        db.commit()
    finally:
        db.close()


async def generate_thumbnail_task(video_id: str) -> None:
    """Background task per generazione thumbnail video.
    
    Esegue retry automatico (max 5 tentativi) con exponential backoff.
    Se fallisce, usa thumbnail default.
    
    Args:
        video_id: ID video
    """
    db = SessionLocal()
    try:
        video_service = VideoService(db)
        
        # Ottieni video
        from app.models.video import Video
        video = db.query(Video).filter(Video.id == video_id).first()
        
        if not video:
            return
        
        # Retry logic
        max_retries = settings.MAX_RETRIES_BACKGROUND_TASKS
        retry_count = 0
        last_error = None
        
        # Usa durata se disponibile per seek ottimale
        duration = video.duration if video.duration else None
        
        while retry_count < max_retries:
            try:
                # Genera thumbnail
                thumbnail_path = await generate_thumbnail(
                    video_path=video.file_path,
                    video_id=video_id,
                    duration=duration
                )
                
                # Aggiorna video con thumbnail
                video_service.update_video_thumbnail(video_id, thumbnail_path)
                
                # Successo, esci
                return
                
            except Exception as e:
                retry_count += 1
                last_error = e
                
                # Exponential backoff: 2^retry_count secondi
                if retry_count < max_retries:
                    wait_time = 2 ** retry_count
                    await asyncio.sleep(wait_time)
        
        # Tutti i tentativi falliti, usa thumbnail default
        default_thumbnail = Path(settings.DEFAULT_THUMBNAIL_PATH)
        
        # Verifica che thumbnail default esista
        if default_thumbnail.exists():
            video_service.update_video_thumbnail(video_id, str(default_thumbnail))
        else:
            # Se non esiste, lascia thumbnail_path NULL
            # Il client gestirà l'assenza di thumbnail
            pass
        
        # Salva errore in ErrorLog (non critico)
        error_data = {
            'error': str(last_error),
            'retries': retry_count,
            'video_id': video_id,
            'operation': 'thumbnail_generation',
            'used_default': True,
        }
        
        error_log = ErrorLog(
            video_id=video_id,
            operation='thumbnail_generation',
            error_data=error_data
        )
        db.add(error_log)
        db.commit()
        
    except Exception as e:
        # Errore critico
        error_log = ErrorLog(
            video_id=video_id,
            operation='thumbnail_generation',
            error_data={'error': str(e), 'critical': True}
        )
        db.add(error_log)
        db.commit()
    finally:
        db.close()
