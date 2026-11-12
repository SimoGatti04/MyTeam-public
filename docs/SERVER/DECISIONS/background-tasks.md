# Background Tasks (Metadata Extraction, Thumbnail Generation)

## Strategia

- **Retry automatico** max 5 tentativi per background tasks
- **Timeout configurabile** per ogni task
- **Error handling** non bloccante (video funzionante anche se task fallisce)

---

## Metadata Extraction con Retry

**File:** `app/services/background_tasks.py`

```python
from app.core.config import get_settings

settings = get_settings()
MAX_RETRIES = settings.MAX_RETRIES_BACKGROUND_TASKS

async def extract_metadata_task(video_id: str) -> None:
    db = SessionLocal()
    try:
        video_service = VideoService(db)
        video = db.query(Video).filter(Video.id == video_id).first()
        if not video:
            return

        retry_count = 0
        last_error = None

        while retry_count < MAX_RETRIES:
            try:
                metadata = await extract_metadata(video.file_path)
                video_service.update_video_metadata(
                    video_id=video_id,
                    duration=metadata.get('duration'),
                    width=metadata.get('width'),
                    height=metadata.get('height'),
                    video_metadata=metadata,
                )
                return
            except Exception as e:
                retry_count += 1
                last_error = e
                if retry_count < MAX_RETRIES:
                    wait_time = 2 ** retry_count
                    await asyncio.sleep(wait_time)

        # Tutti i retry falliti
        error_data = {
            'error': str(last_error),
            'retries': retry_count,
            'video_id': video_id,
            'operation': 'metadata_extraction',
        }
        video_service.update_video_metadata_error(video_id, error_data)
        
        error_log = ErrorLog(
            video_id=video_id,
            operation='metadata_extraction',
            error_data=error_data
        )
        db.add(error_log)
        db.commit()
    finally:
        db.close()
```

---

## Thumbnail Generation con Retry

```python
async def generate_thumbnail_task(video_id: str) -> None:
    db = SessionLocal()
    try:
        video_service = VideoService(db)
        video = db.query(Video).filter(Video.id == video_id).first()
        if not video:
            return

        retry_count = 0
        last_error = None

        while retry_count < MAX_RETRIES:
            try:
                thumbnail_path = await generate_thumbnail(
                    video.file_path,
                    video_id,
                    video.duration,
                )
                video_service.update_video_thumbnail(video_id, thumbnail_path)
                return
            except Exception as e:
                retry_count += 1
                last_error = e
                if retry_count < MAX_RETRIES:
                    wait_time = 2 ** retry_count
                    await asyncio.sleep(wait_time)

        # Tutti i retry falliti - usa thumbnail default
        default_thumbnail = settings.DEFAULT_THUMBNAIL_PATH
        video_service.update_video_thumbnail(video_id, default_thumbnail)
        
        error_log = ErrorLog(
            video_id=video_id,
            operation='thumbnail_generation',
            error_data={
                'error': str(last_error),
                'retries': retry_count,
                'fallback': default_thumbnail,
            }
        )
        db.add(error_log)
        db.commit()
    finally:
        db.close()
```

---

## Configurazione

### `.env`

```env
# Background Tasks
MAX_RETRIES_BACKGROUND_TASKS=5
METADATA_EXTRACTION_TIMEOUT=3600  # 1 ora in secondi
THUMBNAIL_GENERATION_TIMEOUT=600  # 10 minuti in secondi
DEFAULT_THUMBNAIL_PATH=./storage/default_thumbnail.jpg
```

### `app/core/config.py`

```python
class Settings(BaseSettings):
    MAX_RETRIES_BACKGROUND_TASKS: int = 5
    METADATA_EXTRACTION_TIMEOUT: int = 3600
    THUMBNAIL_GENERATION_TIMEOUT: int = 600
    DEFAULT_THUMBNAIL_PATH: str = "./storage/default_thumbnail.jpg"
```
