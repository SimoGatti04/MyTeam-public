# Limiti File Size e Upload Queue

## Limiti Configurati

- **File Size Massimo**: 50 GB per video singolo
- **Upload Queue**: 10 video simultanei
- **Upload Timeout**: 24 ore

---

## Configurazione

### `.env`

```env
# File size limits
MAX_UPLOAD_SIZE=53687091200  # 50GB in bytes

# Upload queue limits
MAX_CONCURRENT_UPLOADS=10

# Timeout
UPLOAD_TIMEOUT=86400  # 24 ore in secondi
```

### `app/core/config.py`

```python
class Settings(BaseSettings):
    # File size limits
    MAX_UPLOAD_SIZE: int = 53687091200  # 50GB
    
    # Upload queue limits
    MAX_CONCURRENT_UPLOADS: int = 10
    
    # Upload Timeout
    UPLOAD_TIMEOUT: int = 86400  # 24 ore
    
    class Config:
        env_file = ".env"
```

---

## Implementazioni

### Disk Space Check

**File:** `app/utils/file_validation.py`

```python
import shutil
from fastapi import HTTPException

def check_disk_space(file_size: int, storage_path: str) -> None:
    """Verifica spazio disco disponibile.
    
    Args:
        file_size: Dimensione file in bytes
        storage_path: Path storage
        
    Raises:
        HTTPException: 507 se spazio insufficiente
    """
    total, used, free = shutil.disk_usage(storage_path)
    required_space = file_size * 1.1  # 10% buffer
    
    if free < required_space:
        raise HTTPException(
            status_code=507,
            detail=f"Spazio disco insufficiente. Richiesto: {required_space / (1024**3):.1f} GB, Disponibile: {free / (1024**3):.1f} GB"
        )
```

**Uso:**
```python
# Prima di salvare file
check_disk_space(file.size, settings.VIDEOS_PATH)
```

---

## Hardware Raccomandato

### Server Minimo

**Per 50GB file + 10 upload simultanei:**
- **CPU**: 4+ core
- **RAM**: 8GB+
- **Storage**: SSD
- **Network**: 100Mbps+ upload
