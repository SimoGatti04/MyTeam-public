"""Thumbnail generation service using FFmpeg"""
import asyncio
from pathlib import Path
from app.core.config import get_settings

settings = get_settings()


async def generate_thumbnail(video_path: str, video_id: str, duration: int = None) -> str:
    """Genera thumbnail video usando FFmpeg.
    
    Args:
        video_path: Path file video
        video_id: ID video (per filename thumbnail)
        duration: Durata video in secondi (opzionale, per seek ottimale)
        
    Returns:
        Path thumbnail generato
        
    Raises:
        Exception: Se FFmpeg fallisce
    """
    # Determina seek time (10 secondi o 10% durata se < 10 secondi)
    if duration and duration < 10:
        seek_time = int(duration * 0.1)
    else:
        seek_time = 10
    
    # Path thumbnail
    thumbnail_path = Path(settings.THUMBNAILS_PATH) / f"{video_id}.jpg"
    thumbnail_path.parent.mkdir(parents=True, exist_ok=True)
    
    # FFmpeg command
    command = [
        settings.FFMPEG_PATH,
        '-i', video_path,
        '-ss', str(seek_time),
        '-vframes', '1',
        '-vf', 'scale=320:-1',  # Scala larghezza 320px, altezza proporzionale
        '-q:v', '2',  # Qualità alta
        '-y',  # Overwrite output file
        str(thumbnail_path)
    ]
    
    # Esegui FFmpeg con timeout
    process = await asyncio.create_subprocess_exec(
        *command,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )
    
    try:
        stdout, stderr = await asyncio.wait_for(
            process.communicate(),
            timeout=settings.THUMBNAIL_GENERATION_TIMEOUT
        )
    except asyncio.TimeoutError:
        process.kill()
        await process.wait()
        raise Exception(f"FFmpeg timeout after {settings.THUMBNAIL_GENERATION_TIMEOUT} seconds")
    
    if process.returncode != 0:
        error_msg = stderr.decode() if stderr else "Unknown error"
        raise Exception(f"FFmpeg failed: {error_msg}")
    
    # Verifica che il file sia stato creato
    if not thumbnail_path.exists():
        raise Exception("Thumbnail file not created")
    
    return str(thumbnail_path)
