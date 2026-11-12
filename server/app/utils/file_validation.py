"""File validation utilities"""
import re
import shutil
from pathlib import Path
from fastapi import UploadFile, HTTPException
from app.core.config import get_settings

settings = get_settings()

ALLOWED_VIDEO_FORMATS = ['mp4', 'avi', 'mov', 'mkv', 'webm']


def sanitize_filename(filename: str) -> str:
    """Sanitizza filename per evitare errori e path traversal.
    
    Args:
        filename: Filename originale
        
    Returns:
        Filename sanitizzato
    """
    # Rimuovi path traversal
    filename = re.sub(r'\.\./|\.\.\\', '', filename)
    
    # Rimuovi caratteri speciali
    filename = re.sub(r'[<>:"|?*\\/]', '_', filename)
    
    # Rimuovi caratteri controllo
    filename = re.sub(r'[\x00-\x1F]', '', filename)
    
    # Limita lunghezza (max 255 caratteri)
    if len(filename) > 255:
        extension = Path(filename).suffix
        name_without_ext = filename[:-len(extension)]
        filename = f"{name_without_ext[:255-len(extension)-1]}{extension}"
    
    # Rimuovi spazi multipli
    filename = re.sub(r'\s+', ' ', filename)
    
    # Trim
    filename = filename.strip()
    
    return filename


def validate_file_path(file_path: str, base_path: str) -> None:
    """Valida che file path non esca da base_path.
    
    Args:
        file_path: Path file da validare
        base_path: Path base consentito
        
    Raises:
        HTTPException: 400 se path traversal rilevato
    """
    # Risolvi path assoluti
    resolved_path = Path(file_path).resolve()
    resolved_base = Path(base_path).resolve()
    
    # Verifica che file path sia dentro base_path
    try:
        resolved_path.relative_to(resolved_base)
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail="Path traversal detected"
        )


def validate_file(file: UploadFile, request_headers: dict = None) -> None:
    """Valida file video.
    
    Args:
        file: File da validare
        request_headers: HTTP request headers (per Content-Length)
                       NOTA: Per multipart/form-data, Content-Length non è affidabile
                       perché include boundary e altri campi form, non solo il file.
        
    Raises:
        HTTPException: 400 se formato non supportato
        HTTPException: 413 se file troppo grande (solo se request_headers fornito e non multipart)
    """
    # Sanitizza filename
    if file.filename:
        file.filename = sanitize_filename(file.filename)
    
    # Validazione formato
    if file.filename:
        file_extension = file.filename.split('.')[-1].lower()
        if file_extension not in ALLOWED_VIDEO_FORMATS:
            raise HTTPException(
                status_code=400,
                detail=f"Formato file non supportato. Formati supportati: {', '.join(ALLOWED_VIDEO_FORMATS)}"
            )
    
    # Validazione dimensione (Content-Length header)
    # IMPORTANTE: Per multipart/form-data, Content-Length include boundary e altri campi,
    # quindi non è affidabile per validare la dimensione del file. La validazione verrà
    # fatta durante il salvataggio del file usando validate_file_size_during_upload.
    # Validiamo solo se request_headers è fornito E non è multipart/form-data
    if request_headers and 'content-length' in request_headers:
        # Verifica se è multipart/form-data
        content_type = request_headers.get('content-type', '')
        is_multipart = 'multipart/form-data' in content_type.lower()
        
        if not is_multipart:
            # Solo per non-multipart (es. upload diretto), valida dimensione
            content_length = int(request_headers['content-length'])
            if content_length > settings.MAX_UPLOAD_SIZE:
                raise HTTPException(
                    status_code=413,
                    detail=f"File troppo grande. Dimensione massima: {settings.MAX_UPLOAD_SIZE / (1024**3):.1f} GB"
                )
            
            # Verifica spazio disco disponibile (per file grandi)
            if content_length > 10 * 1024 * 1024 * 1024:  # 10GB
                from app.core.storage import check_disk_space
                check_disk_space(content_length, settings.VIDEOS_PATH)
    
    # Validazione MIME type (opzionale)
    if file.content_type and not file.content_type.startswith('video/'):
        raise HTTPException(
            status_code=400,
            detail="File non è un video valido"
        )


async def validate_file_size_during_upload(file: UploadFile, max_size: int) -> None:
    """Valida dimensione file durante upload (fallback se Content-Length mancante).
    
    Args:
        file: File da validare
        max_size: Dimensione massima consentita (bytes)
        
    Raises:
        HTTPException: 413 se file troppo grande
    """
    total_read = 0
    max_read_for_validation = 10 * 1024 * 1024  # 10MB max per validazione
    
    async for chunk in file.stream():
        total_read += len(chunk)
        
        # Interrompi subito se troppo grande (primi chunk)
        if total_read > max_size:
            raise HTTPException(
                status_code=413,
                detail=f"File troppo grande. Dimensione massima: {max_size / (1024**3):.1f} GB"
            )
        
        # Se superato 10MB e ancora OK, continua (non sprecare troppo)
        if total_read > max_read_for_validation:
            break  # Abbastanza validato, continua upload

