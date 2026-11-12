"""File storage utilities"""
import os
import aiofiles
from typing import Optional, Callable
from fastapi import UploadFile, HTTPException
from pathlib import Path
from app.core.config import get_settings

settings = get_settings()


async def save_file_to_disk(
    file: UploadFile, 
    file_path: str, 
    on_progress: Optional[Callable[[int, int], None]] = None,
    total_size: Optional[int] = None,
    max_size: Optional[int] = None
) -> None:
    """Salva file su disco in modo asincrono con atomic write e progress tracking.
    
    Args:
        file: File da salvare (UploadFile)
        file_path: Path finale del file
        on_progress: Callback per aggiornare progress (opzionale)
                     Signature: (uploaded_bytes: int, total_bytes: int) -> None
        total_size: Dimensione totale file in bytes (opzionale, per progress)
        max_size: Dimensione massima consentita in bytes (opzionale, per validazione)
        
    Raises:
        HTTPException: 413 se file troppo grande
        HTTPException: 500 se errore salvataggio
    """
    # Crea directory se non esiste
    Path(file_path).parent.mkdir(parents=True, exist_ok=True)
    
    # Temporary file per atomic write
    temp_path = file_path + '.tmp'
    
    total_written = 0
    last_update = 0
    update_threshold = 5 * 1024 * 1024  # 5MB - aggiorna progress ogni 5MB (ridotto frequenza per performance)
    
    try:
        # Salva file in temporary location
        async with aiofiles.open(temp_path, 'wb') as f:
            # Usa file.stream() se disponibile (FastAPI UploadFile)
            if hasattr(file, 'stream') and callable(file.stream):
                async for chunk in file.stream():
                    total_written += len(chunk)
                    
                    # Validazione dimensione durante salvataggio (per multipart/form-data)
                    if max_size and total_written > max_size:
                        # Log per debug
                        import logging
                        logger = logging.getLogger(__name__)
                        logger.error(f"[Storage] File troppo grande durante salvataggio: {total_written} bytes > {max_size} bytes")
                        # Cleanup temporary file
                        if os.path.exists(temp_path):
                            os.remove(temp_path)
                        raise HTTPException(
                            status_code=413,
                            detail=f"File troppo grande. Dimensione massima: {max_size / (1024**3):.1f} GB"
                        )
                    
                    await f.write(chunk)
                    
                    # Aggiorna progress ogni 5MB
                    if on_progress and (total_written - last_update >= update_threshold or total_written == total_size):
                        if total_size:
                            on_progress(total_written, total_size)
                        last_update = total_written
            elif hasattr(file, 'file'):
                # Fallback: leggi da file.file se stream() non disponibile
                file.file.seek(0)
                while True:
                    chunk = file.file.read(64 * 1024)  # 64KB chunks
                    if not chunk:
                        break
                    
                    total_written += len(chunk)
                    
                    # Validazione dimensione durante salvataggio (per multipart/form-data)
                    if max_size and total_written > max_size:
                        # Cleanup temporary file
                        if os.path.exists(temp_path):
                            os.remove(temp_path)
                        raise HTTPException(
                            status_code=413,
                            detail=f"File troppo grande. Dimensione massima: {max_size / (1024**3):.1f} GB"
                        )
                    
                    await f.write(chunk)
                    
                    # Aggiorna progress ogni 5MB
                    if on_progress and (total_written - last_update >= update_threshold or total_written == total_size):
                        if total_size:
                            on_progress(total_written, total_size)
                        last_update = total_written
            else:
                raise HTTPException(
                    status_code=500,
                    detail="Impossibile leggere file stream"
                )
        
        # Aggiorna progress finale (100%)
        if on_progress and total_size:
            on_progress(total_written, total_size)
        
        # Rinomina solo se upload completato (atomic write)
        os.rename(temp_path, file_path)
        
    except HTTPException:
        # Re-raise HTTPException
        raise
    except Exception as e:
        # Cleanup temporary file se errore
        if os.path.exists(temp_path):
            os.remove(temp_path)
        
        raise HTTPException(
            status_code=500,
            detail=f"Errore salvataggio file: {str(e)}"
        )


def check_disk_space(file_size: int, storage_path: str) -> None:
    """Verifica spazio disco disponibile.
    
    Args:
        file_size: Dimensione file in bytes
        storage_path: Path storage
        
    Raises:
        HTTPException: 507 se spazio insufficiente
    """
    import shutil
    
    total, used, free = shutil.disk_usage(storage_path)
    required_space = file_size * 1.1  # 10% buffer
    
    if free < required_space:
        raise HTTPException(
            status_code=507,
            detail=f"Spazio disco insufficiente. Richiesto: {required_space / (1024**3):.1f} GB, Disponibile: {free / (1024**3):.1f} GB"
        )

