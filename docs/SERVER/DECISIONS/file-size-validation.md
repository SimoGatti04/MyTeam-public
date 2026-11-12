# File Size Validation

## Strategia

- **Content-Length Header** (validazione prima upload)
- **Fallback durante upload** (validazione primi chunk se header mancante)
- **Disk space check** prima upload (per file >10GB)

---

## Implementazione

**File:** `app/utils/file_validation.py`

```python
from fastapi import UploadFile, HTTPException
from app.core.config import get_settings
from app.core.storage import check_disk_space

settings = get_settings()

def validate_file(file: UploadFile, request_headers: dict = None) -> None:
    """Valida file video.
    
    Args:
        file: File da validare
        request_headers: HTTP request headers (per Content-Length)
        
    Raises:
        HTTPException: 400 se formato non supportato
        HTTPException: 413 se file troppo grande
    """
    if request_headers and 'content-length' in request_headers:
        content_length = int(request_headers['content-length'])
        if content_length > settings.MAX_UPLOAD_SIZE:
            raise HTTPException(
                status_code=413,
                detail=f"File troppo grande. Dimensione massima: {settings.MAX_UPLOAD_SIZE / (1024**3):.1f} GB"
            )
        
        if content_length > 10 * 1024 * 1024 * 1024:  # 10GB
            check_disk_space(content_length, settings.VIDEOS_PATH)

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
        
        if total_read > max_size:
            raise HTTPException(
                status_code=413,
                detail=f"File troppo grande. Dimensione massima: {max_size / (1024**3):.1f} GB"
            )
        
        if total_read > max_read_for_validation:
            break
```

---

## Configurazione

### `.env`

```env
MAX_UPLOAD_SIZE=53687091200  # 50GB in bytes
```

### `app/core/config.py`

```python
class Settings(BaseSettings):
    MAX_UPLOAD_SIZE: int = 53687091200  # 50GB
```
