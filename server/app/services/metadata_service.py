"""Metadata extraction service using FFprobe"""
import json
import asyncio
from app.core.config import get_settings

settings = get_settings()


async def extract_metadata(video_path: str) -> dict:
    """Estrae metadata video usando FFprobe.
    
    Args:
        video_path: Path file video
        
    Returns:
        Dict con metadata video:
        - duration: int (seconds)
        - file_size: int (bytes)
        - bitrate: int (bits per second)
        - width: int
        - height: int
        - codec: str
        - framerate: float
        
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
    
    # Esegui FFprobe con timeout
    process = await asyncio.create_subprocess_exec(
        *command,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )
    
    try:
        stdout, stderr = await asyncio.wait_for(
            process.communicate(),
            timeout=settings.METADATA_EXTRACTION_TIMEOUT
        )
    except asyncio.TimeoutError:
        process.kill()
        await process.wait()
        raise Exception(f"FFprobe timeout after {settings.METADATA_EXTRACTION_TIMEOUT} seconds")
    
    if process.returncode != 0:
        error_msg = stderr.decode() if stderr else "Unknown error"
        raise Exception(f"FFprobe failed: {error_msg}")
    
    # Parse JSON output
    try:
        metadata = json.loads(stdout.decode())
    except json.JSONDecodeError as e:
        raise Exception(f"Failed to parse FFprobe JSON output: {str(e)}")
    
    # Estrai metadata rilevanti
    format_info = metadata.get('format', {})
    video_stream = next(
        (s for s in metadata.get('streams', []) if s.get('codec_type') == 'video'),
        None
    )
    
    if not video_stream:
        raise Exception("No video stream found in video file")
    
    # Parse duration
    duration = 0
    if 'duration' in format_info:
        try:
            duration = int(float(format_info['duration']))
        except (ValueError, TypeError):
            pass
    
    # Parse file size
    file_size = 0
    if 'size' in format_info:
        try:
            file_size = int(format_info['size'])
        except (ValueError, TypeError):
            pass
    
    # Parse bitrate
    bitrate = 0
    if 'bit_rate' in format_info:
        try:
            bitrate = int(format_info['bit_rate'])
        except (ValueError, TypeError):
            pass
    
    # Parse framerate
    framerate = 0.0
    if 'r_frame_rate' in video_stream:
        framerate = _parse_framerate(video_stream['r_frame_rate'])
    elif 'avg_frame_rate' in video_stream:
        framerate = _parse_framerate(video_stream['avg_frame_rate'])
    
    return {
        'duration': duration,
        'file_size': file_size,
        'bitrate': bitrate,
        'width': video_stream.get('width'),
        'height': video_stream.get('height'),
        'codec': video_stream.get('codec_name'),
        'framerate': framerate,
        'raw_metadata': metadata,  # Include raw metadata for future use
    }


def _parse_framerate(framerate_str: str) -> float:
    """Parse framerate da stringa 'num/den'.
    
    Args:
        framerate_str: Framerate string (es: "30/1", "30000/1001")
        
    Returns:
        Framerate float
    """
    try:
        if '/' in framerate_str:
            num, den = map(int, framerate_str.split('/'))
            return num / den if den > 0 else 0.0
        else:
            return float(framerate_str)
    except (ValueError, TypeError, ZeroDivisionError):
        return 0.0
