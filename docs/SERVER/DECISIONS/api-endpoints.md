# API Endpoints Implementation

## Endpoint Upload

### POST /api/videos

**File:** `app/api/routes/videos.py`

```python
from fastapi import APIRouter, UploadFile, Form, BackgroundTasks, Depends, Request
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.services.video_service import VideoService
from app.services.upload_queue_service import UploadQueueService
from app.schemas.video import VideoResponse
from app.utils.file_validation import validate_file
from app.core.config import get_settings
from app.core.storage import save_file_to_disk, check_disk_space
from app.services.background_tasks import extract_metadata_task, generate_thumbnail_task

router = APIRouter()
settings = get_settings()

@router.post("/api/videos", response_model=VideoResponse)
async def upload_video(
    request: Request,
    file: UploadFile,
    title: str = Form(None),
    original_resolution_width: int = Form(None),
    original_resolution_height: int = Form(None),
    original_framerate: float = Form(None),
    compressed_framerate: float = Form(None),
    original_file_size: int = Form(None),
    background_tasks: BackgroundTasks = BackgroundTasks(),
    db: Session = Depends(get_db),
):
    # Validazione file
    validate_file(file, request_headers=dict(request.headers))
    
    # Disk space check (per file >10GB)
    file_size = None
    if 'content-length' in request.headers:
        file_size = int(request.headers['content-length'])
    elif original_file_size:
        file_size = original_file_size
    
    if file_size and file_size > 10 * 1024 * 1024 * 1024:
        check_disk_space(file_size, settings.VIDEOS_PATH)
    
    # Crea upload queue entry
    upload_queue_service = UploadQueueService(db)
    upload_queue = upload_queue_service.create_upload_queue_entry(
        filename=file.filename or "unknown",
        file_path="",
        file_size=file_size or original_file_size or 0,
    )
    
    # Salva video metadata
    video_service = VideoService(db)
    video = video_service.save_video(
        file=file,
        title=title or file.filename or "Untitled",
        original_resolution_width=original_resolution_width,
        original_resolution_height=original_resolution_height,
        original_framerate=original_framerate,
        compressed_framerate=compressed_framerate,
        original_file_size=original_file_size,
    )
    
    # Aggiorna upload queue
    upload_queue_service.update_upload_queue_status(
        upload_id=upload_queue.id,
        status="processing",
        video_id=video.id,
        progress=0.0,
    )
    
    # Salva file su disco
    await save_file_to_disk(file, video.file_path)
    
    # Aggiorna file size e progress
    file_size = os.path.getsize(video.file_path)
    video = video_service.update_video_file_size(video.id, file_size)
    upload_queue_service.update_upload_progress(
        upload_id=upload_queue.id,
        uploaded_bytes=file_size,
    )
    upload_queue_service.update_upload_queue_status(
        upload_id=upload_queue.id,
        status="completed",
        progress=1.0,
    )
    
    # Background tasks
    background_tasks.add_task(extract_metadata_task, video.id)
    background_tasks.add_task(generate_thumbnail_task, video.id)
    
    return video
```

---

## Multipart/Form-Data Parsing

FastAPI gestisce automaticamente multipart/form-data:
- Parsing automatico di `file` (UploadFile)
- Parsing automatico di `Form` fields
- Streaming automatico (non carica tutto in memoria)
