"""Chunked upload endpoints for bypassing Cloudflare 100MB limit"""
import os
import hashlib
import logging
from datetime import datetime
from typing import Dict, Optional
from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Depends
from fastapi.background import BackgroundTasks
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.config import get_settings
from app.core.storage import save_file_to_disk
from app.services.video_service import VideoService
from app.services.upload_queue_service import UploadQueueService
from app.schemas.video import VideoResponse
from app.utils.file_validation import validate_file

settings = get_settings()
logger = logging.getLogger(__name__)
router = APIRouter()

# In-memory storage per upload sessions (in produzione usa Redis o database)
_upload_sessions: Dict[str, dict] = {}

# Dimensione chunk massima (90MB per stare sotto i 100MB di Cloudflare)
MAX_CHUNK_SIZE = 90 * 1024 * 1024  # 90MB


@router.post("/api/videos/chunked/init")
async def init_chunked_upload(
    title: str = Form(...),
    total_size: int = Form(...),
    total_chunks: int = Form(...),
    filename: str = Form(...),
    original_resolution_width: int = Form(None),
    original_resolution_height: int = Form(None),
    original_framerate: float = Form(None),
    compressed_framerate: float = Form(None),
    original_file_size: int = Form(None),
    recorded_date: str = Form(None),
    db: Session = Depends(get_db),
):
    """Inizializza una sessione di chunked upload.
    
    Args:
        title: Titolo del video
        total_size: Dimensione totale del file in bytes
        total_chunks: Numero totale di chunk
        filename: Nome del file originale (può contenere path completo, verrà normalizzato)
        original_resolution_width: Larghezza risoluzione originale
        original_resolution_height: Altezza risoluzione originale
        original_framerate: Framerate originale
        compressed_framerate: Framerate compresso
        original_file_size: Dimensione file originale
        
    Returns:
        upload_id: ID della sessione di upload
    """
    import uuid
    
    # Normalizza filename: estrai solo il nome file dal path completo
    # Gestisce path Windows (C:\Users\...) e Unix (/path/to/file)
    normalized_filename = os.path.basename(filename) if filename else "video.mp4"
    
    # Rimuovi caratteri non validi per nome file Windows
    # Windows non permette: < > : " / \ | ? *
    invalid_chars = ['<', '>', ':', '"', '/', '\\', '|', '?', '*']
    for char in invalid_chars:
        normalized_filename = normalized_filename.replace(char, '_')
    
    # Genera upload ID univoco
    upload_id = str(uuid.uuid4())
    
    # Crea video entry nel database
    video_service = VideoService(db)
    upload_queue_service = UploadQueueService(db)
    
    # Crea upload queue entry
    upload_queue = upload_queue_service.create_upload_queue_entry(
        filename=normalized_filename,
        file_path="",  # Verrà aggiornato dopo ricomposizione
        file_size=total_size,
    )
    
    # Crea video entry (senza file ancora)
    # Nota: per chunked upload, creiamo il video dopo che tutti i chunk sono stati ricevuti
    # Per ora creiamo solo l'upload queue entry
    
    # Inizializza sessione upload
    _upload_sessions[upload_id] = {
        'upload_id': upload_id,
        'title': title,
        'filename': normalized_filename,
        'total_size': total_size,
        'total_chunks': total_chunks,
        'received_chunks': set(),
        'chunks_data': {},  # {chunk_index: bytes}
        'upload_queue_id': upload_queue.id,
        'original_resolution_width': original_resolution_width,
        'original_resolution_height': original_resolution_height,
        'original_framerate': original_framerate,
        'compressed_framerate': compressed_framerate,
        'original_file_size': original_file_size,
        'recorded_date': recorded_date,
        'db': db,  # Nota: in produzione usa un pattern diverso per gestire DB
    }
    
    logger.info(f"[ChunkedUpload] Sessione inizializzata: {upload_id}, {total_chunks} chunk, {total_size} bytes")
    
    return {
        'upload_id': upload_id,
        'total_chunks': total_chunks,
        'chunk_size': MAX_CHUNK_SIZE,
    }


@router.post("/api/videos/chunked/chunk")
async def upload_chunk(
    upload_id: str = Form(...),
    chunk_index: int = Form(...),
    chunk: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    """Carica un chunk del file.
    
    Args:
        upload_id: ID della sessione di upload
        chunk_index: Indice del chunk (0-based)
        chunk: File chunk da caricare
        
    Returns:
        status: Stato del chunk upload
        received_chunks: Numero di chunk ricevuti
        total_chunks: Numero totale di chunk
    """
    # Verifica che la sessione esista
    if upload_id not in _upload_sessions:
        raise HTTPException(status_code=404, detail="Upload session not found")
    
    session = _upload_sessions[upload_id]
    
    # Verifica che il chunk_index sia valido
    if chunk_index < 0 or chunk_index >= session['total_chunks']:
        raise HTTPException(status_code=400, detail=f"Invalid chunk_index: {chunk_index}")
    
    # Verifica che il chunk non sia già stato ricevuto
    if chunk_index in session['received_chunks']:
        logger.warning(f"[ChunkedUpload] Chunk {chunk_index} già ricevuto per {upload_id}")
        return {
            'status': 'already_received',
            'received_chunks': len(session['received_chunks']),
            'total_chunks': session['total_chunks'],
        }
    
    # Leggi chunk in memoria (limite 90MB)
    chunk_data = await chunk.read()
    chunk_size = len(chunk_data)
    
    if chunk_size > MAX_CHUNK_SIZE:
        raise HTTPException(
            status_code=413,
            detail=f"Chunk troppo grande: {chunk_size} bytes. Massimo: {MAX_CHUNK_SIZE} bytes"
        )
    
    # Salva chunk in sessione
    session['chunks_data'][chunk_index] = chunk_data
    session['received_chunks'].add(chunk_index)
    
    logger.info(f"[ChunkedUpload] Chunk {chunk_index}/{session['total_chunks']-1} ricevuto per {upload_id} ({chunk_size} bytes)")
    
    # Aggiorna progress upload queue
    upload_queue_service = UploadQueueService(db)
    progress = len(session['received_chunks']) / session['total_chunks']
    upload_queue_service.update_upload_progress(
        upload_id=session['upload_queue_id'],
        uploaded_bytes=int(session['total_size'] * progress),
    )
    
    return {
        'status': 'received',
        'received_chunks': len(session['received_chunks']),
        'total_chunks': session['total_chunks'],
        'chunk_index': chunk_index,
    }


@router.post("/api/videos/chunked/complete", response_model=VideoResponse)
async def complete_chunked_upload(
    upload_id: str = Form(...),
    background_tasks: BackgroundTasks = BackgroundTasks(),
    db: Session = Depends(get_db),
):
    """Completa l'upload ricomponendo tutti i chunk.
    
    Args:
        upload_id: ID della sessione di upload
        
    Returns:
        VideoResponse: Video creato
    """
    # Verifica che la sessione esista
    if upload_id not in _upload_sessions:
        raise HTTPException(status_code=404, detail="Upload session not found")
    
    session = _upload_sessions[upload_id]
    
    # Verifica che tutti i chunk siano stati ricevuti
    if len(session['received_chunks']) != session['total_chunks']:
        missing_chunks = set(range(session['total_chunks'])) - session['received_chunks']
        raise HTTPException(
            status_code=400,
            detail=f"Chunk mancanti: {missing_chunks}. Ricevuti: {len(session['received_chunks'])}/{session['total_chunks']}"
        )
    
    logger.info(f"[ChunkedUpload] Ricomposizione file per {upload_id}")
    
    # Ricomponi file dai chunk
    chunks_data = session['chunks_data']
    total_size = sum(len(chunks_data[i]) for i in range(session['total_chunks']))
    
    if total_size != session['total_size']:
        logger.warning(f"[ChunkedUpload] Dimensione totale non corrisponde: attesa {session['total_size']}, ricevuta {total_size}")
    
    # Crea video service
    video_service = VideoService(db)
    upload_queue_service = UploadQueueService(db)
    
    # Ricomponi file dai chunk in un file temporaneo
    import tempfile
    import shutil
    
    with tempfile.NamedTemporaryFile(delete=False, suffix='.mp4') as temp_file:
        temp_path = temp_file.name
        
        # Scrivi tutti i chunk in ordine
        for i in range(session['total_chunks']):
            if i not in chunks_data:
                raise HTTPException(status_code=500, detail=f"Chunk {i} mancante durante ricomposizione")
            temp_file.write(chunks_data[i])
        
        temp_file.flush()
    
    # Calcola dimensione file effettiva
    actual_file_size = os.path.getsize(temp_path)
    
    # Crea file path finale
    file_path = os.path.join(settings.VIDEOS_PATH, f"{upload_id}_{session['filename']}")
    
    # Sposta file temporaneo nella posizione finale
    shutil.move(temp_path, file_path)
    
    # Crea video entry direttamente (non usare save_video che richiede UploadFile)
    from app.models.video import Video
    from datetime import datetime
    import uuid
    from pathlib import Path
    
    # Genera ID video
    video_id = str(uuid.uuid4())
    
    # Determina file format
    file_extension = Path(session['filename']).suffix.lstrip('.') if session['filename'] else 'mp4'
    
    # Genera filename univoco
    filename = f"{video_id}.{file_extension}"
    final_file_path = os.path.join(settings.VIDEOS_PATH, filename)
    
    # Rinomina file con filename corretto
    if file_path != final_file_path:
        shutil.move(file_path, final_file_path)
    
    # Processa recorded_date se presente (formato YYYY-MM-DD)
    recorded_date_dt = None
    recorded_date_str = session.get('recorded_date')
    if recorded_date_str:
        try:
            # Parse YYYY-MM-DD e normalizza a 12:00:00 UTC
            from datetime import timezone
            parsed_date = datetime.strptime(recorded_date_str, '%Y-%m-%d')
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
            logger.info(f"[ChunkedUpload] Recorded date parsed: {recorded_date_str} -> {recorded_date_dt}")
        except ValueError as e:
            # Se il formato non è valido, ignora la data
            logger.warning(f"[ChunkedUpload] Error parsing recorded_date '{recorded_date_str}': {e}")
            pass
    else:
        logger.info(f"[ChunkedUpload] No recorded_date in session")
    
    # Crea video entry
    video = Video(
        id=video_id,
        title=session['title'],
        filename=filename,
        file_path=final_file_path,
        file_size=actual_file_size,
        file_format=file_extension,
        original_resolution_width=session['original_resolution_width'],
        original_resolution_height=session['original_resolution_height'],
        original_framerate=session['original_framerate'],
        compressed_framerate=session['compressed_framerate'],
        original_file_size=session['original_file_size'],
        recorded_date=recorded_date_dt,
        status='processing',
    )
    
    db.add(video)
    db.commit()
    db.refresh(video)
    
    # Aggiorna upload queue
    upload_queue_service.update_upload_queue_status(
        upload_id=session['upload_queue_id'],
        status="completed",
        video_id=video.id,
        progress=1.0,
    )
    
    # Background tasks
    from app.services.background_tasks import extract_metadata_task, generate_thumbnail_task
    background_tasks.add_task(extract_metadata_task, video.id)
    background_tasks.add_task(generate_thumbnail_task, video.id)
    
    # Rimuovi sessione (cleanup)
    del _upload_sessions[upload_id]
    
    logger.info(f"[ChunkedUpload] Upload completato: {upload_id} -> video {video.id}")
    
    # VideoResponse viene generato automaticamente dal modello Video
    return video

