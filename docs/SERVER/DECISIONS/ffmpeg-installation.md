# Installazione FFmpeg/FFprobe

## Strategia

**Installazione separata sulla macchina host** come dipendenza di sistema.

---

## Installazione per OS

### Linux (Debian/Ubuntu)

```bash
sudo apt-get update
sudo apt-get install ffmpeg
```

### Linux (CentOS/RHEL)

```bash
sudo yum install ffmpeg
```

### macOS (Homebrew)

```bash
brew install ffmpeg
```

### Windows

- Download da https://ffmpeg.org/download.html
- Estrai e aggiungi al PATH
- Configura `FFMPEG_PATH` e `FFPROBE_PATH` nel `.env`

---

## Configurazione Server

### `.env`

```env
# Linux
FFMPEG_PATH=/usr/bin/ffmpeg
FFPROBE_PATH=/usr/bin/ffprobe

# macOS (Homebrew)
FFMPEG_PATH=/opt/homebrew/bin/ffmpeg
FFPROBE_PATH=/opt/homebrew/bin/ffprobe

# macOS (MacPorts)
FFMPEG_PATH=/opt/local/bin/ffmpeg
FFPROBE_PATH=/opt/local/bin/ffprobe

# Windows (configurare manualmente)
FFMPEG_PATH=C:\ffmpeg\bin\ffmpeg.exe
FFPROBE_PATH=C:\ffmpeg\bin\ffprobe.exe
```

### `app/core/config.py`

```python
class Settings(BaseSettings):
    FFMPEG_PATH: str = "/usr/bin/ffmpeg"
    FFPROBE_PATH: str = "/usr/bin/ffprobe"
    
    class Config:
        env_file = ".env"
```

---

## Verifica Installazione

**File:** `app/core/ffmpeg_verification.py`

```python
import subprocess
import shutil
from app.core.config import get_settings

settings = get_settings()

def _check_command(command_path: str, command_name: str):
    if not shutil.which(command_path):
        raise RuntimeError(f"{command_name} non trovato in {command_path}")
    try:
        subprocess.run([command_path, "-version"], check=True, capture_output=True)
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        raise RuntimeError(f"Errore durante la verifica di {command_name} in {command_path}: {e}")

def verify_ffmpeg_installation():
    _check_command(settings.FFMPEG_PATH, "FFmpeg")
    _check_command(settings.FFPROBE_PATH, "FFprobe")
```

**Uso in `app/main.py`:**

```python
@app.on_event("startup")
async def startup_event():
    init_db()
    
    from app.core.ffmpeg_verification import verify_ffmpeg_installation
    try:
        verify_ffmpeg_installation()
        print("✅ FFmpeg/FFprobe verified")
    except RuntimeError as e:
        print(f"⚠️  WARNING: {str(e)}")
        print("⚠️  Server funzionerà ma metadata extraction e thumbnail generation falliranno")
```

---

## Verifica Manuale

```bash
ffmpeg -version
ffprobe -version
```
