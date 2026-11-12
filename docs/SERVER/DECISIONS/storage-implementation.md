# Storage Implementation

## Strategia

- **Async File Operations** (aiofiles) per non bloccare thread
- **Atomic Write** (temporary file + rename) per evitare file corrotti
- **Chunk Size 64KB** (default FastAPI) per streaming efficiente

---

## Implementazione

**File:** `app/core/storage.py`

```python
import os
import aiofiles
from fastapi import UploadFile, HTTPException
from pathlib import Path

async def save_file_to_disk(file: UploadFile, file_path: str) -> None:
    """Salva file su disco in modo asincrono con atomic write.
    
    Args:
        file: File da salvare (UploadFile)
        file_path: Path finale del file
        
    Raises:
        HTTPException: 500 se errore salvataggio
    """
    Path(file_path).parent.mkdir(parents=True, exist_ok=True)
    
    temp_path = file_path + '.tmp'
    
    try:
        async with aiofiles.open(temp_path, 'wb') as f:
            if hasattr(file, 'stream') and callable(file.stream):
                async for chunk in file.stream():
                    await f.write(chunk)
            elif hasattr(file, 'file'):
                file.file.seek(0)
                while True:
                    chunk = file.file.read(64 * 1024)
                    if not chunk:
                        break
                    await f.write(chunk)
        
        os.rename(temp_path, file_path)
    except Exception as e:
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
```
