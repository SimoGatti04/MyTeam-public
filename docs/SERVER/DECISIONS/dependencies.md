# Server-Side Dependencies

## Packages Necessari

### Web Framework

**Package:** `fastapi`

```txt
fastapi==0.104.1
```

---

### Multipart Parsing

**Package:** `python-multipart`

```txt
python-multipart==0.0.6
```

**Uso:** Necessario per FastAPI multipart/form-data

---

### Async File Operations

**Package:** `aiofiles`

```txt
aiofiles==23.1.0
```

**Uso:** Async file operations per non bloccare thread

---

### Database ORM

**Package:** `sqlalchemy`

```txt
sqlalchemy==2.0.23
```

**Uso:** ORM per database models

---

### Data Validation

**Package:** `pydantic` e `pydantic-settings`

```txt
pydantic==2.5.0
pydantic-settings==2.1.0
```

**Uso:** Validazione dati e settings

---

### ASGI Server

**Package:** `uvicorn`

```txt
uvicorn[standard]==0.24.0
```

**Uso:** ASGI server per FastAPI

---

### Testing

**Package:** `pytest`, `pytest-asyncio`, `pytest-mock`, `httpx`

```txt
pytest==7.4.3
pytest-asyncio==0.21.1
pytest-mock==3.12.0
httpx==0.25.2
```

**Uso:** Testing framework e client HTTP per test

---

## Requirements Completi

### `requirements.txt`

```txt
fastapi==0.104.1
python-multipart==0.0.6
aiofiles==23.1.0
sqlalchemy==2.0.23
pydantic==2.5.0
pydantic-settings==2.1.0
uvicorn[standard]==0.24.0

# Testing
pytest==7.4.3
pytest-asyncio==0.21.1
pytest-mock==3.12.0
httpx==0.25.2
```

---

## Video Processing

**Package:** FFmpeg/FFprobe (system package)

**Nota:** FFmpeg deve essere installato sul sistema separatamente.

**Verifica:**
```bash
ffmpeg -version
ffprobe -version
```

---

## Future Dependencies

### Backup System

**Package:** `apscheduler`

```txt
apscheduler==3.10.4
```

**Uso:** Scheduling backup automatico
