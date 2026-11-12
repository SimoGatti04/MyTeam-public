# Modelli Dati Server

## Panoramica

Questi sono i modelli dati **interni al server** (database, business logic).

---

## Database Models (SQLAlchemy)

### Video Model

**Tabella:** `videos`

```python
class Video(Base):
    __tablename__ = "videos"
    
    # Primary Key
    id = Column(String, primary_key=True)  # UUID
    
    # Basic Info
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    filename = Column(String(255), nullable=False)
    file_path = Column(String(500), nullable=False)
    file_size = Column(Integer, nullable=False)  # bytes
    file_format = Column(String(10), nullable=False)  # mp4, avi, etc.
    
    # Metadata (extracted from video)
    duration = Column(Integer, nullable=True)  # seconds
    width = Column(Integer, nullable=True)  # Risoluzione compresso salvato
    height = Column(Integer, nullable=True)  # Risoluzione compresso salvato
    thumbnail_path = Column(String(500), nullable=True)
    video_metadata = Column(JSON, nullable=True)  # codec, bitrate, etc.
    
    # Compression Metadata (client-side compression)
    original_resolution_width = Column(Integer, nullable=True)
    original_resolution_height = Column(Integer, nullable=True)
    original_framerate = Column(Float, nullable=True)
    compressed_framerate = Column(Float, nullable=True)
    original_file_size = Column(Integer, nullable=True)  # bytes
    compression_ratio = Column(Float, nullable=True)  # 0.0-1.0
    
    # Future: Transcoding paths (NULL for now)
    transcoded_480p_path = Column(String(500), nullable=True)
    transcoded_720p_path = Column(String(500), nullable=True)
    transcoded_1080p_path = Column(String(500), nullable=True)
    transcoded_1440p_path = Column(String(500), nullable=True)
    transcoded_2160p_path = Column(String(500), nullable=True)
    transcoding_status = Column(String(20), default="not_started")
    
    # Status
    status = Column(String(20), default="ready")  # processing, ready, error
    
    # Timestamps
    created_at = Column(DateTime, default=func.now(), nullable=False)  # Data di aggiunta
    recorded_date = Column(DateTime, nullable=True)                    # Data di realizzazione (modificabile)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)
```

### Upload Queue Model

**Tabella:** `upload_queue`

```python
class UploadQueue(Base):
    __tablename__ = "upload_queue"
    
    # Primary Key
    id = Column(String, primary_key=True)  # UUID
    
    # Video Reference
    video_id = Column(String, nullable=True)  # FK to videos (nullable se non ancora creato)
    
    # File Info
    filename = Column(String(255), nullable=False)
    file_size = Column(Integer, nullable=False)  # bytes
    
    # Status
    status = Column(String(20), default="queued")  # queued, processing, completed, error
    progress = Column(Float, default=0.0)  # 0.0-1.0
    error_message = Column(Text, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
```

---

### Error Log Model

**Tabella:** `error_logs`

```python
class ErrorLog(Base):
    __tablename__ = "error_logs"
    
    # Primary Key
    id = Column(String, primary_key=True)  # UUID
    
    # Video Reference
    video_id = Column(String, nullable=True)  # FK to videos (nullable se errore prima creazione video)
    
    # Operation Type
    operation = Column(String(50), nullable=False)  # "upload", "compression", "metadata_extraction", "thumbnail_generation"
    
    # Error Data (full error log JSON)
    error_data = Column(JSON, nullable=False)
    
    # Timestamps
    created_at = Column(DateTime, default=func.now())
```

---

## Pydantic Schemas (API Validation)

### VideoBase Schema

```python
class VideoBase(BaseModel):
    title: str
    description: Optional[str] = None
```

### VideoCreate Schema

```python
class VideoCreate(VideoBase):
    filename: str
    file_size: int
    file_format: str
    original_resolution_width: Optional[int] = None
    original_resolution_height: Optional[int] = None
    original_framerate: Optional[float] = None
    compressed_framerate: Optional[float] = None
    original_file_size: Optional[int] = None
```

### VideoResponse Schema

```python
class VideoResponse(VideoBase):
    id: str
    filename: str
    file_path: str
    file_size: int
    file_format: str
    duration: Optional[int] = None
    width: Optional[int] = None
    height: Optional[int] = None
    thumbnail_path: Optional[str] = None
    status: str
    video_metadata: Optional[dict] = None
    original_resolution_width: Optional[int] = None
    original_resolution_height: Optional[int] = None
    original_framerate: Optional[float] = None
    compressed_framerate: Optional[float] = None
    original_file_size: Optional[int] = None
    compression_ratio: Optional[float] = None
    created_at: datetime
    recorded_date: Optional[datetime] = None  # Data di realizzazione (modificabile)
    updated_at: datetime
    
    class Config:
        from_attributes = True
```

### UploadQueueResponse Schema

```python
class UploadQueueResponse(BaseModel):
    id: str
    video_id: Optional[str] = None
    filename: str
    file_size: int
    status: str  # queued, processing, completed, error
    progress: float  # 0.0-1.0
    error_message: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True
```

### ErrorLogCreate Schema

```python
class ErrorLogCreate(BaseModel):
    video_id: Optional[str] = None
    operation: str  # "upload", "compression", "metadata_extraction", "thumbnail_generation"
    error_data: Dict[str, Any]  # Full error log JSON
```

### ErrorLogResponse Schema

```python
class ErrorLogResponse(BaseModel):
    id: str
    video_id: Optional[str] = None
    operation: str
    error_data: Dict[str, Any]
    created_at: datetime
    
    class Config:
        from_attributes = True
```

---

## Internal Models (Business Logic)

### Video Processing Status

```python
class VideoProcessingStatus(Enum):
    PROCESSING = "processing"
    READY = "ready"
    ERROR = "error"
```

### Upload Queue Status

```python
class UploadQueueStatus(Enum):
    QUEUED = "queued"
    PROCESSING = "processing"
    COMPLETED = "completed"
    ERROR = "error"
```

---

Per modelli dati per comunicazione API, vedere `GENERAL/DATA-MODELS.md`.

