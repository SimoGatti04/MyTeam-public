# API Reference - Endpoint Completi

## Base URL

```
http://server-ip:8000/api
```

---

## Video Endpoints

### `GET /api/videos`

**Lista video con paginazione**

**Comportamento non distruttivo:** è un endpoint di lettura. File mancanti o storage temporaneamente indisponibile non causano la cancellazione o l'occultamento dei record; le cancellazioni richiedono l'endpoint esplicito `DELETE /api/videos/{video_id}`. Il controllo di regressione verifica che il GET esegua query di lettura senza SQL `INSERT`, `UPDATE` o `DELETE`.

**Query Parameters:**
- `page`: int (default: 1, min: 1)
- `limit`: int (default: 20, min: 1, max: 100)
- `search`: string (optional, ricerca nel titolo/filename)
- `sort`: string (optional, valori: `date_asc`, `date_desc`, `name_asc`, `name_desc`, `size_asc`, `size_desc`)

**Response 200 OK:**
```json
{
  "items": [
    {
      "id": "uuid",
      "title": "Video Title",
      "filename": "video.mp4",
      "file_size": 5368709120,
      "duration": 3600,
      "width": 1920,
      "height": 1080,
      "thumbnail_url": "/api/videos/uuid/thumbnail",
      "status": "ready",
      "created_at": "2024-01-01T00:00:00Z"
    }
  ],
  "total": 100,
  "page": 1,
  "limit": 20
}
```

**Error Responses:**
- `400 Bad Request`: Parametri query invalidi
  ```json
  {
    "detail": "Invalid page number. Must be >= 1"
  }
  ```

---

### `GET /api/videos/{id}`

**Dettagli video**

**Path Parameters:**
- `id`: string (UUID del video)

**Response 200 OK:**
```json
{
  "id": "uuid",
  "title": "Video Title",
  "description": "Video description",
  "filename": "video.mp4",
  "file_path": "./storage/videos/uuid.mp4",
  "file_size": 5368709120,
  "file_format": "mp4",
  "duration": 3600,
  "width": 1920,
  "height": 1080,
  "thumbnail_path": "./storage/thumbnails/uuid.jpg",
  "status": "ready",
  "video_metadata": {
    "codec": "h264",
    "bitrate": 5000000,
    "framerate": 30.0
  },
  "original_resolution_width": 3840,
  "original_resolution_height": 2160,
  "original_framerate": 60.0,
  "compressed_framerate": 30.0,
  "original_file_size": 21474836480,
  "compression_ratio": 0.75,
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:00:00Z"
}
```

**Error Responses:**
- `404 Not Found`: Video non trovato
  ```json
  {
    "detail": "Video not found"
  }
  ```

---

### `POST /api/videos`

**Upload video compresso**

**Content-Type:** `multipart/form-data`

**Form Fields:**
- `file`: File (required, video compresso)
- `title`: string (optional, default: filename)
- `original_resolution_width`: int (optional)
- `original_resolution_height`: int (optional)
- `original_framerate`: float (optional)
- `compressed_framerate`: float (optional)
- `original_file_size`: int (optional, bytes)

**Response 200 OK:**
```json
{
  "id": "uuid",
  "title": "Video Title",
  "description": null,
  "filename": "video.mp4",
  "file_path": "./storage/videos/uuid.mp4",
  "file_size": 5368709120,
  "file_format": "mp4",
  "duration": null,
  "width": null,
  "height": null,
  "thumbnail_path": null,
  "status": "processing",
  "video_metadata": null,
  "original_resolution_width": 3840,
  "original_resolution_height": 2160,
  "original_framerate": 60.0,
  "compressed_framerate": 30.0,
  "original_file_size": 21474836480,
  "compression_ratio": null,
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:00:00Z"
}
```

**Nota:** Il server restituisce `200 OK` (non `201 Created`) perché l'endpoint è asincrono e il video è ancora in fase di processing. I campi `duration`, `width`, `height`, `thumbnail_path`, `video_metadata` e `compression_ratio` vengono popolati successivamente dalle background tasks.

**Error Responses:**
- `400 Bad Request`: File non valido
  ```json
  {
    "detail": "Formato file non supportato. Formati supportati: mp4, avi, mov, mkv, webm"
  }
  ```
  
- `413 Payload Too Large`: File troppo grande
  ```json
  {
    "detail": "File troppo grande. Dimensione massima: 10.0 GB"
  }
  ```
  
- `500 Internal Server Error`: Errore salvataggio
  ```json
  {
    "detail": "Errore salvataggio file: [error message]"
  }
  ```

---

### `GET /api/videos/{id}/download`

**Download video**

**Path Parameters:**
- `id`: string (UUID del video)

**Headers:**
- `Range`: string (optional, formato: `bytes=start-end`)
  - Esempio: `Range: bytes=0-1023`
  - Usato per resume download

**Response 200 OK (download completo):**
- `Content-Type`: `video/mp4` (o altro formato)
- `Content-Length`: `5368709120`
- `Content-Disposition`: `attachment; filename="video.mp4"`
- `Accept-Ranges`: `bytes`

**Response 206 Partial Content (range request):**
- `Content-Type`: `video/mp4`
- `Content-Range`: `bytes 0-1023/5368709120`
- `Content-Length`: `1024`
- `Accept-Ranges`: `bytes`

**Error Responses:**
- `404 Not Found`: Video non trovato
  ```json
  {
    "detail": "Video not found"
  }
  ```
  
- `416 Range Not Satisfiable`: Range invalido
  ```json
  {
    "detail": "Range not satisfiable"
  }
  ```

---

### `GET /api/videos/{id}/stream`

**Streaming video**

**Path Parameters:**
- `id`: string (UUID del video)

**Headers:**
- `Range`: string (required, formato: `bytes=start-end`)
  - Esempio: `Range: bytes=0-1023`

**Response 206 Partial Content:**
- `Content-Type`: `video/mp4`
- `Content-Range`: `bytes 0-1023/5368709120`
- `Content-Length`: `1024`
- `Accept-Ranges`: `bytes`

**Error Responses:**
- `404 Not Found`: Video non trovato
- `416 Range Not Satisfiable`: Range invalido o mancante

---

### `GET /api/videos/{id}/thumbnail`

**Thumbnail video**

**Path Parameters:**
- `id`: string (UUID del video)

**Response 200 OK:**
- `Content-Type`: `image/jpeg`
- `Content-Length`: `[thumbnail size]`

**Response 404 Not Found:**
```json
{
  "detail": "Thumbnail not found"
}
```

---

### `DELETE /api/videos/{id}`

**Elimina video**

**Path Parameters:**
- `id`: string (UUID del video)

**Response 204 No Content:**
- Nessun body

**Error Responses:**
- `404 Not Found`: Video non trovato
  ```json
  {
    "detail": "Video not found"
  }
  ```

---

## Upload Queue Endpoints

### `GET /api/videos/upload/queue`

**Lista upload in coda**

**Query Parameters:**
- `status`: string (optional, valori: `queued`, `processing`, `completed`, `error`)

**Response 200 OK:**
```json
{
  "items": [
    {
      "id": "uuid",
      "video_id": "uuid",
      "filename": "video.mp4",
      "file_size": 5368709120,
      "status": "processing",
      "progress": 0.75,
      "error_message": null,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z"
    }
  ],
  "active": 2,
  "queued": 5,
  "completed": 10,
  "error": 1
}
```

---

### `GET /api/videos/upload/{id}/status`

**Status upload specifico**

**Path Parameters:**
- `id`: string (UUID upload queue)

**Response 200 OK:**
```json
{
  "id": "uuid",
  "video_id": "uuid",
  "filename": "video.mp4",
  "file_size": 5368709120,
  "status": "processing",
  "progress": 0.75,
  "error_message": null,
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:00:00Z"
}
```

**Error Responses:**
- `404 Not Found`: Upload non trovato
  ```json
  {
    "detail": "Upload not found"
  }
  ```

---

## Backup Endpoints

### `GET /api/backup/disks`

**Lista dischi disponibili**

**Response 200 OK:**
```json
{
  "disks": [
    {
      "id": "disk_1",
      "name": "USB Drive",
      "path": "/media/usb",
      "total_space": 1073741824000,
      "available_space": 536870912000,
      "is_external": true
    }
  ]
}
```

---

### `POST /api/backup/config`

**Configurazione backup**

**Request Body:**
```json
{
  "enabled": true,
  "schedule": "daily",
  "schedule_time": "02:00",
  "backup_days": ["monday", "wednesday", "friday"],
  "selected_disks": ["disk_1", "disk_2"]
}
```

**Response 200 OK:**
```json
{
  "message": "Backup configuration updated"
}
```

---

### `POST /api/backup/start`

**Avvia backup manuale**

**Response 200 OK:**
```json
{
  "message": "Backup started",
  "backup_id": "uuid"
}
```

---

### `GET /api/backup/status`

**Status backup corrente**

**Response 200 OK:**
```json
{
  "status": "running",
  "progress": 0.75,
  "current_video": "video_id",
  "total_videos": 100,
  "backed_up": 75
}
```

---

## Debug Endpoints

### `POST /api/debug/upload-errors`

**Salva log errori per debug**

**Request Body:**
```json
{
  "video_id": "uuid",
  "filename": "video.mp4",
  "operation": "upload",
  "timestamp": "2024-01-01T12:00:00Z",
  "retries": [
    {
      "attempt": 1,
      "timestamp": "2024-01-01T12:00:01Z",
      "error": "Network timeout",
      "status_code": 504,
      "stack_trace": "..."
    },
    {
      "attempt": 2,
      "timestamp": "2024-01-01T12:00:30Z",
      "error": "Connection refused",
      "status_code": null,
      "stack_trace": "..."
    }
  ],
  "final_status": "failed"
}
```

**Response 200 OK:**
```json
{
  "message": "Error log saved"
}
```

---

### `GET /api/debug/upload-errors`

**Recupera log errori per debug**

**Query Parameters:**
- `video_id`: string (optional, UUID video)
- `limit`: int (default: 100, max: 1000)

**Response 200 OK:**
```json
[
  {
    "video_id": "uuid",
    "filename": "video.mp4",
    "operation": "upload",
    "timestamp": "2024-01-01T12:00:00Z",
    "retries": [...],
    "final_status": "failed"
  }
]
```

---

## Error Responses Standardizzati

### Formato Errore

```json
{
  "detail": "Error message description"
}
```

### Status Codes

- `400 Bad Request`: Richiesta invalida (parametri, validazione)
- `404 Not Found`: Risorsa non trovata
- `413 Payload Too Large`: File troppo grande
- `416 Range Not Satisfiable`: Range request invalido
- `500 Internal Server Error`: Errore server interno
- `507 Insufficient Storage`: Spazio disco insufficiente

---

## Content Types

### Request
- `multipart/form-data`: Upload file
- `application/json`: Request body JSON

### Response
- `application/json`: Response JSON
- `video/mp4`: Video file
- `image/jpeg`: Thumbnail
- `application/octet-stream`: File download

---

## Rate Limiting

**Attualmente:** Nessun rate limiting (app privata, utente singolo)

**Future:** Opzionale se necessario

---

## CORS

**Configurazione:**
- Origins: Configurabile via `.env` (default: `*`)
- Methods: `GET`, `POST`, `DELETE`
- Headers: `Content-Type`, `Range`

---

## Authentication

**Attualmente:** Nessuna autenticazione (app privata, utente singolo)

**Future:** Opzionale se necessario

