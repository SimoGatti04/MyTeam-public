# Implementazione Server FastAPI

## Stack Tecnologico

- **Python + FastAPI** - Framework web
- **SQLite** - Database (metadata)
- **SQLAlchemy** - ORM
- **Pydantic** - Validazione dati
- **FFmpeg** - Video processing
- **APScheduler** - Backup scheduling

---

## Struttura Progetto

```
server/
├── app/
│   ├── main.py                    # Entry point FastAPI
│   ├── core/
│   │   ├── config.py              # Configurazione (legge .env, valida)
│   │   ├── database.py            # Database connection (SQLAlchemy)
│   │   └── storage.py             # Storage management
│   ├── api/
│   │   └── routes/
│   │       ├── videos.py          # Video endpoints (POST /api/videos)
│   │       ├── upload.py          # Upload queue endpoints (future)
│   │       └── backup.py          # Backup endpoints (future)
│   ├── models/                    # SQLAlchemy ORM models
│   │   ├── video.py               # Video database model
│   │   ├── upload_queue.py        # Upload queue model
│   │   └── error_log.py           # Error log model
│   ├── schemas/                   # Pydantic schemas (API validation)
│   │   ├── video.py               # Video request/response schemas
│   │   ├── upload_queue.py        # Upload queue schemas
│   │   └── error_log.py           # Error log schemas
│   ├── services/                  # Business logic
│   │   ├── video_service.py       # Video operations
│   │   ├── upload_queue_service.py # Upload queue management
│   │   ├── metadata_service.py    # Metadata extraction (FFprobe)
│   │   ├── thumbnail_service.py   # Thumbnail generation (FFmpeg)
│   │   ├── background_tasks.py    # Background tasks (retry logic)
│   │   └── backup_service.py      # Backup operations (future)
│   └── utils/
│       └── file_validation.py     # File validation utilities
├── storage/
│   ├── videos/                    # Video files
│   └── thumbnails/                # Thumbnails
├── requirements.txt               # Python dependencies
└── .env                           # Environment variables (non committato)
```

**Note:** Ogni file Python dovrebbe avere docstrings per documentare classi e funzioni. Vedere `REFERENCE/CODE-DOCUMENTATION.md` per best practices.

---

## Configurazione

### Environment Variables (.env)

**Scopo:** File di configurazione per l'utente/ambiente (valori configurazione)

**Caratteristiche:**
- Facilmente modificabile (senza toccare codice)
- Specifico per ambiente (dev, prod)
- Non committato in Git (contiene configurazioni locali)
- Valori "raw" (stringhe)

```env
# Server
SERVER_HOST=0.0.0.0
SERVER_PORT=8000
DEBUG=false

# Database
DATABASE_URL=sqlite:///./videos.db

# Storage
STORAGE_PATH=./storage
VIDEOS_PATH=./storage/videos
THUMBNAILS_PATH=./storage/thumbnails

# Video Processing
FFMPEG_PATH=/usr/bin/ffmpeg
FFPROBE_PATH=/usr/bin/ffprobe
MAX_UPLOAD_SIZE=53687091200  # 50GB

# Upload Queue
MAX_CONCURRENT_UPLOADS=10

# Upload Timeout
UPLOAD_TIMEOUT=86400  # 24 ore in secondi

# Background Tasks
MAX_RETRIES_BACKGROUND_TASKS=5
METADATA_EXTRACTION_TIMEOUT=3600  # 1 ora in secondi
THUMBNAIL_GENERATION_TIMEOUT=600  # 10 minuti in secondi
DEFAULT_THUMBNAIL_PATH=./storage/default_thumbnail.jpg

# CORS
CORS_ORIGINS=*
```

### Config (app/core/config.py)

**Scopo:** Codice Python che legge e valida configurazione (validazione, default, type-safety)

**Caratteristiche:**
- Valida tipi automaticamente (string → int, etc.)
- Valori di default (se `.env` non esiste)
- Type-safe (TypeScript-like)
- Centralizzato in codice

```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    SERVER_HOST: str = "0.0.0.0"  # Default
    SERVER_PORT: int = 8000        # Default + tipo
    DEBUG: bool = False            # Default + tipo
    DATABASE_URL: str = "sqlite:///./videos.db"
    STORAGE_PATH: str = "./storage"
    VIDEOS_PATH: str = "./storage/videos"
    THUMBNAILS_PATH: str = "./storage/thumbnails"
    MAX_UPLOAD_SIZE: int = 53687091200  # 50GB
    MAX_CONCURRENT_UPLOADS: int = 10
    UPLOAD_TIMEOUT: int = 86400  # 24 ore
    
    # Background Tasks
    MAX_RETRIES_BACKGROUND_TASKS: int = 5
    METADATA_EXTRACTION_TIMEOUT: int = 3600  # 1 ora
    THUMBNAIL_GENERATION_TIMEOUT: int = 600  # 10 minuti
    DEFAULT_THUMBNAIL_PATH: str = "./storage/default_thumbnail.jpg"
    
    class Config:
        env_file = ".env"  # Legge da .env

@lru_cache()
def get_settings() -> Settings:
    """Singleton per settings - cached"""
    return Settings()
```

**Come funzionano insieme:**
- `.env` = Valori configurazione (utente modifica)
- `config.py` = Validazione e default (codice)
- Pydantic converte automaticamente tipi (`"8000"` → `8000` int)
- Se `.env` non esiste o manca valore, usa default da `config.py`

---

## Database Schema

### Video Model

```python
class Video(Base):
    __tablename__ = "videos"
    
    # Primary Key
    id = Column(String, primary_key=True)
    
    # Basic Info
    title = Column(String(255), nullable=False)
    filename = Column(String(255), nullable=False)
    file_path = Column(String(500), nullable=False)
    file_size = Column(Integer, nullable=False)
    file_format = Column(String(10), nullable=False)
    
    # Metadata
    duration = Column(Integer, nullable=True)
    width = Column(Integer, nullable=True)
    height = Column(Integer, nullable=True)
    thumbnail_path = Column(String(500), nullable=True)
    video_metadata = Column(JSON, nullable=True)
    
    # Compression Metadata
    original_resolution_width = Column(Integer, nullable=True)
    original_resolution_height = Column(Integer, nullable=True)
    original_framerate = Column(Float, nullable=True)
    compressed_framerate = Column(Float, nullable=True)
    original_file_size = Column(Integer, nullable=True)
    compression_ratio = Column(Float, nullable=True)
    
    # Status
    status = Column(String(20), default="ready")
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
```

### Upload Queue Model

```python
class UploadQueue(Base):
    __tablename__ = "upload_queue"
    
    id = Column(String, primary_key=True)
    video_id = Column(String, nullable=True)
    filename = Column(String(255), nullable=False)
    file_size = Column(Integer, nullable=False)
    status = Column(String(20), default="queued")
    progress = Column(Float, default=0.0)
    error_message = Column(Text, nullable=True)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
```

---

## API Endpoints

### Video Endpoints

#### `GET /api/videos`
Lista video con paginazione

**Query Parameters:**
- `page`: int (default: 1)
- `limit`: int (default: 20)
- `search`: string (optional)
- `sort`: string (date_asc, date_desc, name_asc, name_desc)

**Response:**
```json
{
  "items": [...],
  "total": 100,
  "page": 1,
  "limit": 20
}
```

#### `GET /api/videos/{id}`
Dettagli video

#### `POST /api/videos`
Upload video compresso

**Request:**
- `multipart/form-data`
- `file`: Video file (compresso client-side)
- `title`: string (opzionale)
- `original_resolution_width`: int (opzionale)
- `original_resolution_height`: int (opzionale)
- `original_framerate`: float (opzionale)
- `compressed_framerate`: float (opzionale)
- `original_file_size`: int (opzionale)

**Response:**
```json
{
  "id": "uuid",
  "title": "...",
  "status": "processing"
}
```

#### `GET /api/videos/{id}/download`
Download video con Range requests support

**Headers:**
- `Range`: bytes=0-1023 (optional, per resume)

**Response:**
- 200 OK o 206 Partial Content
- Content-Type: video/mp4
- Content-Disposition: attachment

#### `GET /api/videos/{id}/stream`
Streaming video con Range requests support

**Headers:**
- `Range`: bytes=0-1023 (required)

**Response:**
- 206 Partial Content
- Content-Type: video/mp4
- Content-Range: bytes 0-1023/{file_size}

#### `GET /api/videos/{id}/thumbnail`
Thumbnail video

**Response:**
- 200 OK
- Content-Type: image/jpeg

#### `DELETE /api/videos/{id}`
Elimina video

**Response:**
- 204 No Content

---

## Video Processing Pipeline

### Upload Flow

```
1. Receive upload request
   ↓
2. Validate file (size, format)
   ↓
3. Create upload queue entry
   ↓
4. Save file to temporary location
   ↓
5. Move to storage/videos/
   ↓
6. Create video database entry
   ↓
7. Background task: Extract metadata
   ↓
8. Background task: Generate thumbnail
   ↓
9. Update video status to "ready"
```

### Metadata Extraction

Usa FFprobe:
```bash
ffprobe -v quiet -print_format json -show_format -show_streams video.mp4
```

Estrae:
- Duration
- Resolution (width, height)
- Codec
- Bitrate
- Framerate

### Thumbnail Generation

Usa FFmpeg:
```bash
ffmpeg -i video.mp4 -ss 00:00:10 -vframes 1 thumbnail.jpg
```

---

## Upload Queue Management

### Server-Side Queue

**Features:**
- Limite upload simultanei (configurabile, default: 3)
- FIFO processing
- Status tracking (queued, processing, completed, error)
- Progress tracking

**Implementation:**
- Background task processor
- Database queue table
- Status updates

---

## Backup System

### Features

- **Disk Detection**: Rileva dischi esterni automaticamente
- **Scheduling**: Backup periodico (daily, weekly, custom)
- **Incremental**: Solo video nuovi/modificati
- **Integrity**: Checksum verification

### Endpoints

```
GET /api/backup/disks
  - Lista dischi disponibili

POST /api/backup/config
  Body: {
    "enabled": true,
    "schedule": "daily",
    "schedule_time": "02:00",
    "selected_disks": ["disk_id_1"]
  }

POST /api/backup/start
  - Avvia backup manuale

GET /api/backup/status
  - Status backup corrente
```

### Implementation

- **APScheduler**: Per scheduling
- **psutil**: Per disk detection
- **Background task**: Per backup execution

---

## File Storage

### Directory Structure

```
storage/
├── videos/
│   └── {video_id}.mp4
└── thumbnails/
    └── {video_id}.jpg
```

### Naming Convention

- Video: `{uuid}.{extension}`
- Thumbnail: `{video_id}.jpg`

---

## Background Tasks

### FastAPI BackgroundTasks

**Uso:**
- Metadata extraction
- Thumbnail generation
- Upload processing

**Esempio:**
```python
@app.post("/api/videos")
async def upload_video(
    file: UploadFile,
    background_tasks: BackgroundTasks
):
    # Save file
    video = save_video(file)
    
    # Background: Extract metadata
    background_tasks.add_task(extract_metadata, video.id)
    
    return video
```

---

## Dependencies

### requirements.txt

```txt
fastapi==0.104.1
uvicorn[standard]==0.24.0
python-multipart==0.0.6
sqlalchemy==2.0.23
pydantic==2.5.0
pydantic-settings==2.1.0
ffmpeg-python==0.2.0
apscheduler==3.10.4
psutil==5.9.6
python-dotenv==1.0.0
```

---

## Deployment

### Direct Python

```bash
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Docker (Opzionale)

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

## Sicurezza

### File Upload

- Validazione formato (whitelist)
- Validazione dimensione
- Sanitizzazione filename
- Path traversal protection

### CORS

- Configurazione per permettere richieste dall'app
- Origins configurabili

---

Per dettagli configurazione, vedere `REFERENCE/API-ENDPOINTS.md` e `REFERENCE/DATABASE-SCHEMA.md`.

