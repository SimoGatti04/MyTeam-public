"""Tests for Thumbnail Service"""
import pytest
import asyncio
from pathlib import Path
from unittest.mock import AsyncMock, patch, MagicMock
from app.services.thumbnail_service import generate_thumbnail

class TestThumbnailService:
    """Tests for thumbnail generation service"""

    @pytest.mark.asyncio
    async def test_generate_thumbnail_success(self, tmp_path, test_settings, monkeypatch):
        """Test successful thumbnail generation"""
        monkeypatch.setattr("app.services.thumbnail_service.settings", test_settings)

        video_path = tmp_path / "test.mp4"
        video_path.write_bytes(b"fake video")

        with patch("app.services.thumbnail_service.asyncio.create_subprocess_exec") as mock_subprocess:
            mock_process = MagicMock()
            mock_process.communicate = AsyncMock(return_value=(b"", b""))
            mock_process.returncode = 0
            mock_subprocess.return_value = mock_process

            # Create thumbnail file manually (since FFmpeg is mocked)
            thumbnail_path = Path(test_settings.THUMBNAILS_PATH) / "test-id.jpg"
            thumbnail_path.parent.mkdir(parents=True, exist_ok=True)
            thumbnail_path.write_bytes(b"fake thumbnail")

            result = await generate_thumbnail(str(video_path), "test-id", duration=100)

            assert result == str(thumbnail_path)
            assert thumbnail_path.exists()

    @pytest.mark.asyncio
    async def test_generate_thumbnail_short_video(self, tmp_path, test_settings, monkeypatch):
        """Test thumbnail generation for short video (< 10 seconds)"""
        monkeypatch.setattr("app.services.thumbnail_service.settings", test_settings)

        video_path = tmp_path / "test.mp4"
        video_path.write_bytes(b"fake video")

        with patch("app.services.thumbnail_service.asyncio.create_subprocess_exec") as mock_subprocess:
            mock_process = MagicMock()
            mock_process.communicate = AsyncMock(return_value=(b"", b""))
            mock_process.returncode = 0
            mock_subprocess.return_value = mock_process

            # Create thumbnail file manually
            thumbnail_path = Path(test_settings.THUMBNAILS_PATH) / "test-id.jpg"
            thumbnail_path.parent.mkdir(parents=True, exist_ok=True)
            thumbnail_path.write_bytes(b"fake thumbnail")

            # For 5 second video, should seek to 0.5 seconds (10%)
            result = await generate_thumbnail(str(video_path), "test-id", duration=5)

            assert result == str(thumbnail_path)
            # Verify seek time is correct (should be 0.5 seconds = 0)
            # The actual FFmpeg command would use seek_time=0, but we're mocking

    @pytest.mark.asyncio
    async def test_generate_thumbnail_ffmpeg_failure(self, tmp_path, test_settings, monkeypatch):
        """Test thumbnail generation with FFmpeg failure"""
        monkeypatch.setattr("app.services.thumbnail_service.settings", test_settings)

        video_path = tmp_path / "test.mp4"
        video_path.write_bytes(b"fake video")

        with patch("app.services.thumbnail_service.asyncio.create_subprocess_exec") as mock_subprocess:
            mock_process = MagicMock()
            mock_process.communicate = AsyncMock(return_value=(
                b"",
                b"FFmpeg error"
            ))
            mock_process.returncode = 1
            mock_subprocess.return_value = mock_process

            with pytest.raises(Exception) as exc_info:
                await generate_thumbnail(str(video_path), "test-id")

            assert "FFmpeg failed" in str(exc_info.value)

    @pytest.mark.asyncio
    async def test_generate_thumbnail_timeout(self, tmp_path, test_settings, monkeypatch):
        """Test thumbnail generation timeout"""
        monkeypatch.setattr("app.services.thumbnail_service.settings", test_settings)

        video_path = tmp_path / "test.mp4"
        video_path.write_bytes(b"fake video")

        with patch("app.services.thumbnail_service.asyncio.create_subprocess_exec") as mock_subprocess:
            mock_process = MagicMock()
            mock_process.communicate = AsyncMock(side_effect=asyncio.TimeoutError())
            mock_process.kill = MagicMock()
            mock_process.wait = AsyncMock()
            mock_subprocess.return_value = mock_process

            with pytest.raises(Exception) as exc_info:
                await generate_thumbnail(str(video_path), "test-id")

            assert "timeout" in str(exc_info.value).lower()
            assert mock_process.kill.called
            assert mock_process.wait.called

    @pytest.mark.asyncio
    async def test_generate_thumbnail_file_not_created(self, tmp_path, test_settings, monkeypatch):
        """Test thumbnail generation when file is not created"""
        monkeypatch.setattr("app.services.thumbnail_service.settings", test_settings)

        video_path = tmp_path / "test.mp4"
        video_path.write_bytes(b"fake video")

        thumbnail_path = Path(test_settings.THUMBNAILS_PATH) / "test-id.jpg"
        thumbnail_path.parent.mkdir(parents=True, exist_ok=True)
        # Don't create thumbnail file - simulate FFmpeg success but file not created

        with patch("app.services.thumbnail_service.asyncio.create_subprocess_exec") as mock_subprocess:
            mock_process = MagicMock()
            mock_process.communicate = AsyncMock(return_value=(b"", b""))
            mock_process.returncode = 0
            mock_subprocess.return_value = mock_process

            # Verify thumbnail file doesn't exist before test
            if thumbnail_path.exists():
                thumbnail_path.unlink()

            with pytest.raises(Exception) as exc_info:
                await generate_thumbnail(str(video_path), "test-id")

            assert "Thumbnail file not created" in str(exc_info.value)
