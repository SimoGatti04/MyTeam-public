# Struttura Progetto Server

## Struttura Directory

```
server/
├── app/
│   ├── __init__.py
│   ├── main.py                    # Entry point FastAPI
│   │
│   ├── core/                      # Core functionality
│   │   ├── __init__.py
│   │   ├── config.py              # Configurazione (.env + validazione)
│   │   ├── database.py            # Database connection (SQLAlchemy)
│   │   └── storage.py             # Storage management
│   │
│   ├── api/                       # API Routes
│   │   ├── __init__.py
│   │   └── routes/
│   │       ├── __init__.py
│   │       ├── videos.py          # Video endpoints (POST /api/videos)
│   │       ├── upload.py          # Upload queue endpoints (future)
│   │       └── backup.py          # Backup endpoints (future)
│   │
│   ├── models/                    # SQLAlchemy ORM models
│   │   ├── __init__.py
│   │   ├── video.py               # Video database model
│   │   ├── upload_queue.py        # Upload queue model
│   │   └── error_log.py           # Error log model
│   │
│   ├── schemas/                   # Pydantic schemas (API validation)
│   │   ├── __init__.py
│   │   ├── video.py               # Video request/response schemas
│   │   ├── upload_queue.py        # Upload queue schemas
│   │   └── error_log.py           # Error log schemas
│   │
│   ├── services/                  # Business logic
│   │   ├── __init__.py
│   │   ├── video_service.py       # Video operations
│   │   ├── upload_queue_service.py # Upload queue management
│   │   ├── metadata_service.py    # Metadata extraction (FFprobe)
│   │   ├── thumbnail_service.py   # Thumbnail generation (FFmpeg)
│   │   ├── background_tasks.py    # Background tasks (metadata, thumbnail)
│   │   └── backup_service.py      # Backup operations (future)
│   │
│   └── utils/
│       ├── __init__.py
│       └── file_validation.py     # File validation utilities
│
├── tests/                         # Test suite
│   ├── __init__.py
│   ├── conftest.py                # Pytest fixtures
│   ├── test_file_validation.py    # File validation tests
│   ├── test_video_service.py      # Video service tests
│   ├── test_upload_queue_service.py # Upload queue tests
│   ├── test_metadata_service.py   # Metadata service tests
│   ├── test_thumbnail_service.py  # Thumbnail service tests
│   ├── test_background_tasks.py    # Background tasks tests
│   ├── test_upload_api.py          # Upload API tests
│   ├── test_edge_cases.py          # Edge cases tests
│   ├── README.md                   # Test documentation
│   └── TEST_SUMMARY.md             # Test summary
│
├── storage/                        # File storage
│   ├── videos/                    # Video files
│   ├── thumbnails/                # Thumbnails
│   └── qualities/                 # Transcoded qualities (future)
│
├── requirements.txt               # Python dependencies
├── pytest.ini                     # Pytest configuration
├── .env                           # Environment variables (non committato)
├── .env.example                   # Template environment variables
├── .gitignore                     # Git ignore rules
└── README.md                      # README server
```

---

## File Principali

### `app/main.py`
**Entry point FastAPI application**

- Crea FastAPI app
- Configura CORS
- Include API routes
- Inizializza database
- Inizializza storage directories

### `app/core/config.py`
**Configurazione applicazione**

- Legge da `.env` file
- Valida configurazione con Pydantic
- Fornisce default values
- Type-safe settings

### `app/core/database.py`
**Database connection**

- SQLAlchemy engine
- Session factory
- Dependency injection per FastAPI
- Database initialization

### `app/core/storage.py`
**File storage management**

- Directory structure
- File operations
- Storage paths management

### `app/api/routes/videos.py`
**Video endpoints**

- `GET /api/videos` - Lista video
- `GET /api/videos/{id}` - Dettagli video
- `POST /api/videos` - Upload video
- `GET /api/videos/{id}/download` - Download video
- `GET /api/videos/{id}/stream` - Streaming video
- `GET /api/videos/{id}/thumbnail` - Thumbnail
- `DELETE /api/videos/{id}` - Elimina video

### `app/api/routes/upload.py`
**Upload queue endpoints** (future implementation)

- `GET /api/videos/upload/queue` - Lista upload in coda
- `GET /api/videos/upload/{id}/status` - Status upload

### `app/api/routes/backup.py`
**Backup endpoints**

- `GET /api/backup/disks` - Lista dischi disponibili
- `POST /api/backup/config` - Configurazione backup
- `POST /api/backup/start` - Avvia backup manuale
- `GET /api/backup/status` - Status backup

### `app/models/video.py`
**Video database model**

- SQLAlchemy model per tabella `videos`
- Compression metadata fields
- Status tracking

### `app/models/upload_queue.py`
**Upload queue database model**

- SQLAlchemy model per tabella `upload_queue`
- Queue status tracking

### `app/models/error_log.py`
**Error log database model**

- SQLAlchemy model per tabella `error_logs`
- Error tracking per operazioni fallite

### `app/schemas/video.py`
**Video API schemas**

- Pydantic schemas per validazione request/response
- VideoBase, VideoCreate, VideoResponse

### `app/schemas/upload_queue.py`
**Upload queue API schemas**

- UploadQueueResponse schema

### `app/schemas/error_log.py`
**Error log API schemas**

- ErrorLogCreate, ErrorLogResponse schemas

### `app/services/video_service.py`
**Video business logic**

- Upload video logic
- Download/streaming logic
- Video operations

### `app/services/upload_queue_service.py`
**Upload queue management**

- Create upload queue entries
- Update upload progress
- Track upload status
- Count active uploads

### `app/services/metadata_service.py`
**Metadata extraction**

- FFprobe integration
- JSON output parsing
- Metadata extraction logic
- Timeout handling

### `app/services/thumbnail_service.py`
**Thumbnail generation**

- FFmpeg integration
- Thumbnail generation logic
- Seek time optimization
- Default thumbnail fallback

### `app/services/background_tasks.py`
**Background tasks**

- Metadata extraction task with retry
- Thumbnail generation task with retry
- Error logging
- Exponential backoff retry logic

### `app/utils/file_validation.py`
**File validation utilities**

- Filename sanitization
- Path traversal protection
- File format validation
- File size validation
- Content-Length header validation

### `app/services/backup_service.py`
**Backup operations** (future implementation)

- Disk detection
- Backup execution
- Integrity verification
- Scheduling integration

---

## Convenzioni

### Naming
- **File**: `snake_case.py`
- **Classi**: `PascalCase`
- **Funzioni**: `snake_case`
- **Variabili**: `snake_case`

### Import Organization
```python
# Standard library
import os
from datetime import datetime

# Third-party
from fastapi import FastAPI, UploadFile
from sqlalchemy.orm import Session

# Local
from app.core.database import get_db
from app.models.video import Video
```

---

Per struttura progetto generale, vedere `GENERAL/PROJECT-STRUCTURE.md`.

