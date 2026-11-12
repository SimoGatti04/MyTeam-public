"""Application configuration"""
try:
    from pydantic_settings import BaseSettings
except ImportError:
    # Fallback for older pydantic versions
    from pydantic import BaseSettings
from functools import lru_cache
from pathlib import Path
import os


def _resolve_database_url() -> str:
    """Return DATABASE_URL, building it from Docker secret if present."""
    secret = Path("/run/secrets/myteam_db_password")
    if secret.exists():
        password = secret.read_text().strip()
        return f"postgresql://myteam:{password}@myteam_postgres:5432/myteam"
    return os.environ.get("DATABASE_URL", "sqlite:///./videos.db")


class Settings(BaseSettings):
    """Application settings"""

    # Server
    SERVER_HOST: str = "0.0.0.0"
    SERVER_PORT: int = 8000
    DEBUG: bool = False

    # Database — resolved at import time before pydantic reads env
    DATABASE_URL: str = _resolve_database_url()
    
    # Storage
    STORAGE_PATH: str = "./storage"
    VIDEOS_PATH: str = "./storage/videos"
    THUMBNAILS_PATH: str = "./storage/thumbnails"
    QUALITIES_PATH: str = "./storage/qualities"
    
    # Video Processing
    FFMPEG_PATH: str = "/usr/bin/ffmpeg"
    FFPROBE_PATH: str = "/usr/bin/ffprobe"
    MAX_UPLOAD_SIZE: int = 53687091200  # 50GB in bytes
    
    # Upload Queue
    MAX_CONCURRENT_UPLOADS: int = 10
    
    # Upload Timeout
    UPLOAD_TIMEOUT: int = 86400  # 24 ore in secondi
    
    # Background Tasks
    MAX_RETRIES_BACKGROUND_TASKS: int = 5
    METADATA_EXTRACTION_TIMEOUT: int = 3600  # 1 ora in secondi
    THUMBNAIL_GENERATION_TIMEOUT: int = 600  # 10 minuti in secondi
    DEFAULT_THUMBNAIL_PATH: str = "./storage/default_thumbnail.jpg"
    
    # CORS
    CORS_ORIGINS: str = "*"
    
    class Config:
        env_file = ".env"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance"""
    return Settings()


# Create storage directories if they don't exist
def init_storage_directories(settings: Settings):
    """Initialize storage directories"""
    Path(settings.VIDEOS_PATH).mkdir(parents=True, exist_ok=True)
    Path(settings.THUMBNAILS_PATH).mkdir(parents=True, exist_ok=True)
    Path(settings.QUALITIES_PATH).mkdir(parents=True, exist_ok=True)

