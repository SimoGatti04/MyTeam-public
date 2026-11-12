# Thumbnail Generation Implementation

## Strategia

- **FFmpeg** per generazione thumbnail
- **Frame a 10 secondi** (o 10% durata se < 10 secondi)
- **Timeout configurabile** (10 minuti default)
- **Retry automatico** max 5 tentativi
- **Thumbnail default** se fallisce

---

## Implementazione

**File:** `app/services/thumbnail_service.py`

```python
import subprocess
import asyncio
from pathlib import Path
from app.core.config import get_settings

settings = get_settings()

async def generate_thumbnail(video_path: str, video_id: str, duration: int = None) -> str:
    """Genera thumbnail video usando FFmpeg.
    
    Args:
        video_path: Path file video
        video_id: ID video (per filename thumbnail)
        duration: Durata video in secondi (opzionale, per seek ottimale)
        
    Returns:
        Path thumbnail generato
        
    Raises:
        Exception: Se FFmpeg fallisce
    """
    if duration and duration < 10:
        seek_time = duration * 0.1
    else:
        seek_time = 10
    
    thumbnail_path = Path(settings.THUMBNAILS_PATH) / f"{video_id}.jpg"
    thumbnail_path.parent.mkdir(parents=True, exist_ok=True)
    
    command = [
        settings.FFMPEG_PATH,
        '-i', video_path,
        '-ss', str(int(seek_time)),
        '-vframes', '1',
        '-vf', 'scale=320:-1',
        '-q:v', '2',
        str(thumbnail_path)
    ]
    
    process = await asyncio.create_subprocess_exec(
        *command,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )
    
    stdout, stderr = await asyncio.wait_for(
        process.communicate(),
        timeout=settings.THUMBNAIL_GENERATION_TIMEOUT
    )
    
    if process.returncode != 0:
        raise Exception(f"FFmpeg failed: {stderr.decode()}")
    
    if not thumbnail_path.exists():
        raise Exception("Thumbnail file not created")
    
    return str(thumbnail_path)
```

---

## Configurazione

### `.env`

```env
FFMPEG_PATH=/usr/bin/ffmpeg
THUMBNAIL_GENERATION_TIMEOUT=600  # 10 minuti in secondi
DEFAULT_THUMBNAIL_PATH=./storage/default_thumbnail.jpg
```

### `app/core/config.py`

```python
class Settings(BaseSettings):
    FFMPEG_PATH: str = "/usr/bin/ffmpeg"
    THUMBNAIL_GENERATION_TIMEOUT: int = 600
    DEFAULT_THUMBNAIL_PATH: str = "./storage/default_thumbnail.jpg"
```
