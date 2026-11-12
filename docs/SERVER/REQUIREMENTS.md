# Requisiti Server - MoSCoW

## Priorità MoSCoW

### Must Have

#### M1. API Video Management
- Endpoint lista video con paginazione
- Endpoint dettagli video
- Endpoint upload video (multipart/form-data)
- Endpoint download video con Range requests support
- Endpoint streaming video con Range requests support
- Endpoint elimina video

#### M2. Upload Queue Management
- Gestione coda upload server-side
- Limite upload simultanei (configurabile)
- Status tracking per ogni upload
- Progress tracking per ogni upload

#### M3. Metadata Extraction
- Estrazione automatica metadata video (FFprobe)
- Durata, risoluzione, codec, bitrate, framerate
- Background task per estrazione metadata

#### M4. File Storage Management
- Salvataggio video su disco
- Organizzazione file per video
- Gestione storage paths

#### M5. Backup System
- Rilevamento dischi esterni (psutil)
- Scheduling backup automatico (APScheduler)
- Backup incrementale
- Verifica integrità backup (checksum)

#### M6. Database Management
- SQLite database per metadata
- Schema video e upload_queue
- Migrations support (opzionale)

---

### Should Have

#### S1. Thumbnail Generation
- Generazione automatica thumbnail (FFmpeg)
- Background task per thumbnail generation

#### S2. Error Handling
- Gestione errori robusta
- Logging errori
- Error responses strutturati

---

### Could Have

#### C1. API Documentation
- Swagger/OpenAPI automatico (FastAPI)
- Documentazione endpoint interattiva

#### C2. Performance Monitoring
- Logging performance
- Metrics endpoint

---

### Won't Have (Future)

#### W1. Transcoding Server-Side
- Generazione versioni multiple video
- Transcoding on-demand

#### W2. Authentication
- Sistema login/autenticazione
- Gestione sessioni

---

## Requisiti Non Funzionali

### Performance
- Async upload/download (FastAPI async)
- Background tasks per operazioni pesanti
- Streaming efficiente con Range requests

### Sicurezza
- File validation (formato, dimensione)
- Path traversal protection
- CORS configurabile

### Affidabilità
- Gestione errori robusta
- Retry logic per operazioni fallite
- Database backup automatico

---

## Stack Tecnologico

### Framework
- **FastAPI** - Framework web asincrono
- **Uvicorn** - ASGI server

### Database
- **SQLite** - Database file-based
- **SQLAlchemy** - ORM

### Video Processing
- **FFmpeg** - Video processing
- **FFprobe** - Metadata extraction

### Scheduling
- **APScheduler** - Backup scheduling

### Utilities
- **Pydantic** - Validazione dati
- **psutil** - Disk detection

---

Per requisiti generali, vedere `GENERAL/REQUIREMENTS.md`.

