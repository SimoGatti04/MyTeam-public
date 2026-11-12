# Metadata Extraction Implementation

## Strategia

- **FFprobe** per estrazione metadata video
- **JSON output** per parsing facile
- **Timeout configurabile** (1 ora default)
- **Retry automatico** max 5 tentativi

---

## Implementazione

**File:** `app/services/metadata_service.py`

```python
import subprocess
import json
import asyncio
from app.core.config import get_settings

settings = get_settings()

async def extract_metadata(video_path: str) -> dict:
    """Estrae metadata video usando FFprobe.
    
    Args:
        video_path: Path file video
        
    Returns:
        Dict con metadata video
        
    Raises:
        Exception: Se FFprobe fallisce
    """
    command = [
        settings.FFPROBE_PATH,
        '-v', 'quiet',
        '-print_format', 'json',
        '-show_format',
        '-show_streams',
        video_path
    ]
    
    process = await asyncio.create_subprocess_exec(
        *command,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )
    
    stdout, stderr = await asyncio.wait_for(
        process.communicate(),
        timeout=settings.METADATA_EXTRACTION_TIMEOUT
    )
    
    if process.returncode != 0:
        raise Exception(f"FFprobe failed: {stderr.decode()}")
    
    metadata = json.loads(stdout.decode())
    
    format_info = metadata.get('format', {})
    video_stream = next(
        (s for s in metadata.get('streams', []) if s.get('codec_type') == 'video'),
        None
    )
    
    if not video_stream:
        raise Exception("No video stream found")
    
    return {
        'duration': int(float(format_info.get('duration', 0))),
        'file_size': int(format_info.get('size', 0)),
        'bitrate': int(format_info.get('bit_rate', 0)),
        'width': video_stream.get('width'),
        'height': video_stream.get('height'),
        'codec': video_stream.get('codec_name'),
        'framerate': _parse_framerate(video_stream.get('r_frame_rate', '0/1')),
    }


def _parse_framerate(framerate_str: str) -> float:
    """Parse framerate da stringa 'num/den'.
    
    Args:
        framerate_str: Framerate string (es: "30/1")
        
    Returns:
        Framerate float
    """
    try:
        num, den = map(int, framerate_str.split('/'))
        return num / den if den > 0 else 0.0
    except:
        return 0.0
```

---

## Configurazione

### `.env`

```env
FFPROBE_PATH=/usr/bin/ffprobe
METADATA_EXTRACTION_TIMEOUT=3600  # 1 ora in secondi
```

### `app/core/config.py`

```python
class Settings(BaseSettings):
    FFPROBE_PATH: str = "/usr/bin/ffprobe"
    METADATA_EXTRACTION_TIMEOUT: int = 3600
```
