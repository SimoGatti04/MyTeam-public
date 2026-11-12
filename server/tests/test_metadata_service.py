"""Tests for Metadata Service"""
import pytest
import json
import asyncio
from unittest.mock import AsyncMock, patch, MagicMock
from app.services.metadata_service import extract_metadata, _parse_framerate

class TestMetadataService:
    """Tests for metadata extraction service"""

    @pytest.mark.asyncio
    async def test_extract_metadata_success(self):
        """Test successful metadata extraction"""
        # Mock FFprobe output
        mock_metadata = {
            "format": {
                "duration": "3600.0",
                "size": "1000000000",
                "bit_rate": "5000000"
            },
            "streams": [
                {
                    "codec_type": "video",
                    "codec_name": "h264",
                    "width": 1920,
                    "height": 1080,
                    "r_frame_rate": "30/1"
                },
                {
                    "codec_type": "audio",
                    "codec_name": "aac"
                }
            ]
        }

        with patch("app.services.metadata_service.asyncio.create_subprocess_exec") as mock_subprocess:
            # Mock process
            mock_process = MagicMock()
            mock_process.communicate = AsyncMock(return_value=(
                json.dumps(mock_metadata).encode(),
                b""
            ))
            mock_process.returncode = 0
            mock_subprocess.return_value = mock_process

            result = await extract_metadata("/tmp/test.mp4")

            assert result["duration"] == 3600
            assert result["width"] == 1920
            assert result["height"] == 1080
            assert result["codec"] == "h264"
            assert result["framerate"] == 30.0
            assert result["bitrate"] == 5000000

    @pytest.mark.asyncio
    async def test_extract_metadata_no_video_stream(self):
        """Test metadata extraction with no video stream"""
        mock_metadata = {
            "format": {
                "duration": "3600.0",
                "size": "1000000000"
            },
            "streams": [
                {
                    "codec_type": "audio",
                    "codec_name": "aac"
                }
            ]
        }

        with patch("app.services.metadata_service.asyncio.create_subprocess_exec") as mock_subprocess:
            mock_process = MagicMock()
            mock_process.communicate = AsyncMock(return_value=(
                json.dumps(mock_metadata).encode(),
                b""
            ))
            mock_process.returncode = 0
            mock_subprocess.return_value = mock_process

            with pytest.raises(Exception) as exc_info:
                await extract_metadata("/tmp/test.mp4")

            assert "No video stream found" in str(exc_info.value)

    @pytest.mark.asyncio
    async def test_extract_metadata_ffprobe_failure(self):
        """Test metadata extraction with FFprobe failure"""
        with patch("app.services.metadata_service.asyncio.create_subprocess_exec") as mock_subprocess:
            mock_process = MagicMock()
            mock_process.communicate = AsyncMock(return_value=(
                b"",
                b"FFprobe error"
            ))
            mock_process.returncode = 1
            mock_subprocess.return_value = mock_process

            with pytest.raises(Exception) as exc_info:
                await extract_metadata("/tmp/test.mp4")

            assert "FFprobe failed" in str(exc_info.value)

    @pytest.mark.asyncio
    async def test_extract_metadata_timeout(self):
        """Test metadata extraction timeout"""
        with patch("app.services.metadata_service.asyncio.create_subprocess_exec") as mock_subprocess:
            mock_process = MagicMock()
            mock_process.communicate = AsyncMock(side_effect=asyncio.TimeoutError())
            mock_process.kill = MagicMock()
            mock_process.wait = AsyncMock()
            mock_subprocess.return_value = mock_process

            with pytest.raises(Exception) as exc_info:
                await extract_metadata("/tmp/test.mp4")

            assert "timeout" in str(exc_info.value).lower()
            assert mock_process.kill.called
            assert mock_process.wait.called

    @pytest.mark.asyncio
    async def test_extract_metadata_invalid_json(self):
        """Test metadata extraction with invalid JSON"""
        with patch("app.services.metadata_service.asyncio.create_subprocess_exec") as mock_subprocess:
            mock_process = MagicMock()
            mock_process.communicate = AsyncMock(return_value=(
                b"invalid json",
                b""
            ))
            mock_process.returncode = 0
            mock_subprocess.return_value = mock_process

            with pytest.raises(Exception) as exc_info:
                await extract_metadata("/tmp/test.mp4")

            assert "Failed to parse" in str(exc_info.value)

class TestParseFramerate:
    """Tests for _parse_framerate function"""

    def test_parse_framerate_normal(self):
        """Test parse normal framerate"""
        assert _parse_framerate("30/1") == 30.0
        assert _parse_framerate("60/1") == 60.0

    def test_parse_framerate_fractional(self):
        """Test parse fractional framerate"""
        assert _parse_framerate("30000/1001") == pytest.approx(29.97, rel=0.01)

    def test_parse_framerate_invalid(self):
        """Test parse invalid framerate"""
        assert _parse_framerate("invalid") == 0.0
        assert _parse_framerate("") == 0.0
        assert _parse_framerate("0/0") == 0.0

    def test_parse_framerate_float(self):
        """Test parse framerate as float string"""
        assert _parse_framerate("30.0") == 30.0
