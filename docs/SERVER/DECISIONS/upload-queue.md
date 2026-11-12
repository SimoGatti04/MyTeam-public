# Upload Queue Management

## Strategia

- **Upload Queue Server-Side** con limite upload simultanei
- **FIFO processing** garantito
- **Limite configurabile** per risorse server

---

## Database Model

**File:** `app/models/upload_queue.py`

```python
class UploadQueue(Base):
    __tablename__ = "upload_queue"
    
    id = Column(String, primary_key=True)  # UUID
    video_id = Column(String, nullable=True)  # FK to videos
    local_filename = Column(String(255), nullable=False)
    remote_filename = Column(String(255), nullable=False)
    file_path = Column(String(500), nullable=False)
    total_bytes = Column(Integer, nullable=False)
    uploaded_bytes = Column(Integer, default=0)
    status = Column(String(20), default="queued")  # queued, processing, completed, error
    progress = Column(Float, default=0.0)  # 0.0-1.0
    error_message = Column(Text, nullable=True)
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
```

---

## Queue Processing

**File:** `app/services/upload_queue_service.py`

```python
class UploadQueueService:
    def __init__(self, db: Session):
        self.db = db
        self.max_concurrent = get_settings().MAX_CONCURRENT_UPLOADS
    
    def create_upload_queue_entry(
        self, 
        filename: str, 
        file_path: str, 
        file_size: int
    ) -> UploadQueue:
        upload_entry = UploadQueue(
            local_filename=filename,
            remote_filename=filename,
            file_path=file_path,
            total_bytes=file_size,
            status="queued",
        )
        self.db.add(upload_entry)
        self.db.commit()
        self.db.refresh(upload_entry)
        return upload_entry
    
    def update_upload_queue_status(
        self,
        upload_id: str,
        status: str,
        video_id: str = None,
        progress: float = None,
    ) -> None:
        upload = self.db.query(UploadQueue).filter(
            UploadQueue.id == upload_id
        ).first()
        
        if upload:
            upload.status = status
            if video_id:
                upload.video_id = video_id
            if progress is not None:
                upload.progress = progress
            if status == "processing" and not upload.started_at:
                upload.started_at = datetime.now()
            if status in ["completed", "error"]:
                upload.completed_at = datetime.now()
            self.db.commit()
    
    def update_upload_progress(
        self,
        upload_id: str,
        uploaded_bytes: int,
    ) -> None:
        upload = self.db.query(UploadQueue).filter(
            UploadQueue.id == upload_id
        ).first()
        
        if upload:
            upload.uploaded_bytes = uploaded_bytes
            upload.progress = min(uploaded_bytes / upload.total_bytes, 1.0)
            upload.updated_at = datetime.now()
            self.db.commit()
    
    def get_active_uploads_count(self) -> int:
        return self.db.query(UploadQueue).filter(
            UploadQueue.status == "processing"
        ).count()
```

---

## Configurazione

### `.env`

```env
# Upload queue limits
MAX_CONCURRENT_UPLOADS=10
```

### `app/core/config.py`

```python
class Settings(BaseSettings):
    MAX_CONCURRENT_UPLOADS: int = 10
```
