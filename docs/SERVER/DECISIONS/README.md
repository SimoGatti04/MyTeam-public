# Decisioni Tecniche Server

## Panoramica

Questa cartella contiene **decisioni tecniche finali specifiche del server** FastAPI.

---

## File Disponibili

### [api-endpoints.md](api-endpoints.md)
**API Endpoints Implementation**
- Endpoint upload
- Multipart/form-data parsing

### [background-tasks.md](background-tasks.md)
**Background Tasks**
- Metadata extraction con retry
- Thumbnail generation con retry
- Configurazione

### [upload-queue.md](upload-queue.md)
**Upload Queue Management**
- Database model
- Queue processing
- Configurazione

### [storage-implementation.md](storage-implementation.md)
**Storage Implementation**
- Async file operations
- Atomic write
- Disk space check

### [metadata-extraction.md](metadata-extraction.md)
**Metadata Extraction Implementation**
- FFprobe command
- Parsing framerate
- Configurazione

### [thumbnail-generation.md](thumbnail-generation.md)
**Thumbnail Generation Implementation**
- FFmpeg command
- Seek time optimization
- Configurazione

### [progress-tracking.md](progress-tracking.md)
**Progress Tracking Server-Side**
- Stima basata su chunk ricevuti
- Aggiornamento ogni 1MB
- Update upload queue progress

### [file-size-validation.md](file-size-validation.md)
**File Size Validation**
- Content-Length header validation
- Fallback durante upload
- Disk space check

### [ffmpeg-installation.md](ffmpeg-installation.md)
**Installazione FFmpeg/FFprobe**
- Installazione per OS
- Configurazione server
- Verifica installazione

### [dependencies.md](dependencies.md)
**Server-Side Dependencies**
- Packages necessari
- Requirements completi
- Future dependencies

### [video-list.md](video-list.md)
**Video List Implementation**
- Endpoint GET /api/videos (paginazione, ricerca, sorting)
- Endpoint GET /api/videos/{id} (dettagli)
- Endpoint GET /api/videos/{id}/thumbnail (thumbnail)
- Schemas Pydantic (VideoListItem, VideoListResponse)
- Comportamento corrente read-only per `GET /api/videos`; la vecchia pulizia automatica di record con file mancanti è **SUPERSEDED**. Vedere [`video-list.md`](video-list.md).

### [progress-tracking.md](progress-tracking.md)
**Progress Tracking Server-Side**
- Progress tracking durante salvataggio file
- Aggiornamento ogni 1MB
- Callback opzionale per aggiornare upload queue in tempo reale

---

## Quando Creare File Qui

✅ **Crea file qui se:**
- Decisione riguarda solo implementazione server
- Decisione riguarda database/server-side logic
- Decisione riguarda deployment/server configuration
- Decisione riguarda background tasks/server scheduling

❌ **NON creare file qui se:**
- Decisione riguarda comunicazione client-server → `GENERAL/DECISIONS/`
- Decisione riguarda solo app → `APP/DECISIONS/`

---

Per decisioni generali:
- **Vedere**: `GENERAL/DECISIONS/`
