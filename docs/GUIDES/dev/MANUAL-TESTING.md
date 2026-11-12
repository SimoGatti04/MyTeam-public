# Test Manuale - Server

## Panoramica

Questa guida descrive come testare manualmente l'endpoint POST `/api/videos` per l'upload di video.

## Prerequisiti

1. **Server avviato**: Il server FastAPI deve essere in esecuzione
2. **FFmpeg installato**: FFmpeg deve essere installato sul sistema (per creare video di test)
3. **File video di test**: Un file video valido per testare l'upload

## Setup

### 1. Avvia il Server

```bash
cd server
source venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Dovresti vedere:
```
✅ Database initialized
✅ FFmpeg/FFprobe verified
✅ Storage directories initialized
INFO:     Uvicorn running on http://0.0.0.0:8000
```

### 2. Verifica Server

```bash
curl http://localhost:8000/health
```

Risposta attesa: `{"status":"healthy"}`

---

## Creazione File Video di Test

### Opzione 1: Usa FFmpeg (Raccomandato)

Crea un video di test semplice (2 secondi, 320x240):

```bash
ffmpeg -f lavfi -i testsrc=duration=2:size=320x240:rate=1 \
       -f lavfi -i sine=frequency=1000:duration=2 \
       -c:v libx264 -preset ultrafast -tune zerolatency \
       -c:a aac -shortest -y /tmp/test_video.mp4
```

### Opzione 2: Usa un Video Esistente

Se hai già un file video, puoi usarlo direttamente.

---

## Test Upload Endpoint

### Test Base con curl

```bash
curl -X POST http://localhost:8000/api/videos \
  -F "file=@/path/to/test_video.mp4" \
  -F "title=Test Video" \
  -F "original_resolution_width=320" \
  -F "original_resolution_height=240" \
  -F "original_framerate=30.0" \
  -F "compressed_framerate=30.0" \
  -F "original_file_size=$(stat -f%z /path/to/test_video.mp4)"
```

**Risposta attesa (200 OK):**
```json
{
  "id": "uuid-video-id",
  "title": "Test Video",
  "filename": "uuid-video-id.mp4",
  "file_path": "./storage/videos/uuid-video-id.mp4",
  "file_size": 12345,
  "file_format": "mp4",
  "status": "processing",
  "original_resolution_width": 320,
  "original_resolution_height": 240,
  "original_framerate": 30.0,
  "compressed_framerate": 30.0,
  "created_at": "2025-11-05T12:00:00",
  "updated_at": "2025-11-05T12:00:00"
}
```

### Test con Swagger UI

1. Vai a http://localhost:8000/docs
2. Trova l'endpoint `POST /api/videos`
3. Clicca "Try it out"
4. Carica un file video
5. Compila i campi opzionali (title, metadata)
6. Clicca "Execute"

---

## Verifica Risultato

### 1. Verifica File Salvato

```bash
ls -lh server/storage/videos/
```

Dovresti vedere il file video salvato.

### 2. Verifica Database

```bash
cd server
source venv/bin/activate
python -c "from app.core.database import SessionLocal; from app.models.video import Video; db = SessionLocal(); videos = db.query(Video).all(); print(f'Videos: {len(videos)}'); [print(f'  - {v.title} ({v.status})') for v in videos]"
```

### 3. Verifica Metadata Extraction

Dopo qualche secondo, verifica che i metadata siano stati estratti:

```bash
python -c "from app.core.database import SessionLocal; from app.models.video import Video; db = SessionLocal(); video = db.query(Video).first(); print(f'Status: {video.status}'); print(f'Duration: {video.duration}'); print(f'Resolution: {video.width}x{video.height}')"
```

### 4. Verifica Thumbnail

```bash
ls -lh server/storage/thumbnails/
```

Dovresti vedere un file thumbnail generato.

---

## Test Errori

### Test File Non Valido

```bash
echo "fake video" > /tmp/fake_video.txt
curl -X POST http://localhost:8000/api/videos \
  -F "file=@/tmp/fake_video.txt" \
  -F "title=Test"
```

**Risposta attesa (400 Bad Request):**
```json
{
  "detail": "File non è un video valido"
}
```

### Test File Troppo Grande

```bash
# Crea file grande (simulato)
dd if=/dev/zero of=/tmp/large_video.mp4 bs=1M count=51
curl -X POST http://localhost:8000/api/videos \
  -F "file=@/tmp/large_video.mp4" \
  -F "title=Large Video" \
  -H "Content-Length: 53687091201"
```

**Risposta attesa (413 Payload Too Large):**
```json
{
  "detail": "File troppo grande. Dimensione massima: 50.0 GB"
}
```

---

## Troubleshooting

### Server Non Risponde

1. Verifica che il server sia in esecuzione:
   ```bash
   ps aux | grep uvicorn
   ```

2. Verifica i log del server per errori

3. Verifica che la porta 8000 non sia già in uso:
   ```bash
   lsof -i :8000
   ```

### FFmpeg Non Trovato

1. Verifica installazione:
   ```bash
   ffmpeg -version
   ```

2. Configura percorso nel `.env`:
   ```env
   FFMPEG_PATH=/usr/local/bin/ffmpeg
   FFPROBE_PATH=/usr/local/bin/ffprobe
   ```

### Upload Fallisce

1. Verifica permessi directory storage:
   ```bash
   ls -ld server/storage/
   ```

2. Verifica spazio disco:
   ```bash
   df -h server/storage/
   ```

3. Verifica log del server per dettagli errore

---

## Note

- **Background Tasks**: Metadata extraction e thumbnail generation sono eseguiti in background e possono richiedere alcuni secondi
- **Timeout**: Upload di file grandi possono richiedere tempo (max 24 ore)
- **Storage**: I file sono salvati in `server/storage/videos/` con atomic write
- **Database**: I metadata sono salvati in SQLite (`server/videos.db`)

