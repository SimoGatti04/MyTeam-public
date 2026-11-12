"""FFmpeg/FFprobe verification utilities"""
import subprocess
from pathlib import Path
from app.core.config import get_settings

settings = get_settings()


def verify_ffmpeg_installation() -> None:
    """Verifica che FFmpeg/FFprobe siano installati e accessibili.
    
    Raises:
        RuntimeError: Se FFmpeg/FFprobe non sono installati o non accessibili
    """
    tools = [
        ("ffmpeg", settings.FFMPEG_PATH),
        ("ffprobe", settings.FFPROBE_PATH),
    ]
    
    for tool_name, tool_path in tools:
        # Verifica che il file esista
        if not Path(tool_path).exists():
            raise RuntimeError(
                f"{tool_name} non trovato a {tool_path}. "
                f"Installare FFmpeg sul sistema. "
                f"Verificare percorso in .env (FFMPEG_PATH, FFPROBE_PATH)"
            )
        
        # Verifica che sia eseguibile
        try:
            result = subprocess.run(
                [tool_path, "-version"],
                capture_output=True,
                timeout=5,
                text=True
            )
            if result.returncode != 0:
                raise RuntimeError(
                    f"{tool_name} non eseguibile a {tool_path}. "
                    f"Verificare permessi e installazione."
                )
        except subprocess.TimeoutExpired:
            raise RuntimeError(
                f"{tool_name} timeout durante verifica a {tool_path}"
            )
        except Exception as e:
            raise RuntimeError(
                f"Errore verifica {tool_name} a {tool_path}: {str(e)}"
            )

