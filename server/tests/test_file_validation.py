"""Tests for file validation utilities"""
import pytest
from fastapi import UploadFile, HTTPException
from io import BytesIO
from app.utils.file_validation import (
    sanitize_filename,
    validate_file_path,
    validate_file,
    validate_file_size_during_upload,
)


class TestSanitizeFilename:
    """Tests for sanitize_filename function"""
    
    def test_normal_filename(self):
        """Test normal filename sanitization"""
        result = sanitize_filename("test_video.mp4")
        assert result == "test_video.mp4"
    
    def test_path_traversal_removal(self):
        """Test path traversal removal"""
        result = sanitize_filename("../../../etc/passwd")
        # Path traversal removed, and / replaced with _ for security
        assert result == "etc_passwd"
    
    def test_special_characters_replacement(self):
        """Test special characters replacement"""
        result = sanitize_filename("test<video>:file|name?.mp4")
        # Special chars (<, :, |, ?) all replaced with _
        # Results in: test_video__file_name_.mp4 (double _ from : and |)
        assert result == "test_video__file_name_.mp4"
    
    def test_control_characters_removal(self):
        """Test control characters removal"""
        result = sanitize_filename("test\x00video\x1F.mp4")
        assert result == "testvideo.mp4"
    
    def test_long_filename_truncation(self):
        """Test long filename truncation"""
        long_name = "a" * 300 + ".mp4"
        result = sanitize_filename(long_name)
        assert len(result) <= 255
        assert result.endswith(".mp4")
    
    def test_multiple_spaces_removal(self):
        """Test multiple spaces removal"""
        result = sanitize_filename("test   video   file.mp4")
        assert result == "test video file.mp4"
    
    def test_empty_filename(self):
        """Test empty filename"""
        result = sanitize_filename("")
        assert result == ""


class TestValidateFilePath:
    """Tests for validate_file_path function"""
    
    def test_valid_path(self):
        """Test valid file path"""
        base_path = "/storage/videos"
        file_path = "/storage/videos/test.mp4"
        validate_file_path(file_path, base_path)  # Should not raise
    
    def test_path_traversal_detection(self):
        """Test path traversal detection"""
        base_path = "/storage/videos"
        file_path = "/storage/videos/../../../etc/passwd"
        
        with pytest.raises(HTTPException) as exc_info:
            validate_file_path(file_path, base_path)
        
        assert exc_info.value.status_code == 400


class TestValidateFile:
    """Tests for validate_file function"""
    
    def test_valid_video_file(self):
        """Test valid video file"""
        file = UploadFile(
            filename="test.mp4",
            file=BytesIO(b"fake content"),
            headers={"content-length": "1000"}
        )
        validate_file(file, request_headers={"content-length": "1000"})  # Should not raise
    
    def test_unsupported_format(self):
        """Test unsupported format"""
        file = UploadFile(
            filename="test.txt",
            file=BytesIO(b"fake content"),
            headers={"content-type": "text/plain"}
        )
        
        with pytest.raises(HTTPException) as exc_info:
            validate_file(file)
        
        assert exc_info.value.status_code == 400
    
    def test_file_too_large(self, monkeypatch):
        """Test file too large"""
        from app.core.config import get_settings
        settings = get_settings()
        
        file = UploadFile(
            filename="test.mp4",
            file=BytesIO(b"fake content"),
            headers={"content-length": str(settings.MAX_UPLOAD_SIZE + 1)}
        )
        
        with pytest.raises(HTTPException) as exc_info:
            validate_file(file, request_headers={"content-length": str(settings.MAX_UPLOAD_SIZE + 1)})
        
        assert exc_info.value.status_code == 413
    
    def test_invalid_content_type(self):
        """Test invalid content type"""
        file = UploadFile(
            filename="test.mp4",
            file=BytesIO(b"fake content"),
            headers={"content-type": "text/plain"}
        )
        
        with pytest.raises(HTTPException) as exc_info:
            validate_file(file)
        
        assert exc_info.value.status_code == 400
    
    def test_filename_sanitization(self):
        """Test filename sanitization during validation"""
        file = UploadFile(
            filename="../../../test.mp4",
            file=BytesIO(b"fake content"),
            headers={"content-length": "1000"}
        )
        
        validate_file(file, request_headers={"content-length": "1000"})
        assert file.filename == "test.mp4"


@pytest.mark.asyncio
class TestValidateFileSizeDuringUpload:
    """Tests for validate_file_size_during_upload function"""
    
    async def test_valid_file_size(self):
        """Test valid file size"""
        # Create a mock UploadFile with stream method
        from unittest.mock import AsyncMock, MagicMock
        
        content = b"x" * 1000
        file = MagicMock(spec=UploadFile)
        file.filename = "test.mp4"
        
        # Create async generator for stream
        async def mock_stream():
            chunk_size = 1024
            for i in range(0, len(content), chunk_size):
                yield content[i:i+chunk_size]
        
        file.stream = mock_stream
        await validate_file_size_during_upload(file, max_size=10000)  # Should not raise
    
    async def test_file_too_large(self):
        """Test file too large"""
        from unittest.mock import MagicMock
        
        content = b"x" * 20000
        file = MagicMock(spec=UploadFile)
        file.filename = "test.mp4"
        
        # Create async generator for stream
        async def mock_stream():
            chunk_size = 1024
            for i in range(0, len(content), chunk_size):
                yield content[i:i+chunk_size]
        
        file.stream = mock_stream
        
        with pytest.raises(HTTPException) as exc_info:
            await validate_file_size_during_upload(file, max_size=10000)
        
        assert exc_info.value.status_code == 413
    
    async def test_large_file_early_detection(self):
        """Test large file early detection (stops after 10MB)"""
        from unittest.mock import MagicMock
        
        # Create a file larger than 10MB but smaller than max_size
        large_content = b"x" * (11 * 1024 * 1024)  # 11MB
        
        file = MagicMock(spec=UploadFile)
        file.filename = "test.mp4"
        
        # Create async generator for stream
        async def mock_stream():
            chunk_size = 1024 * 1024  # 1MB chunks
            for i in range(0, len(large_content), chunk_size):
                yield large_content[i:i+chunk_size]
        
        file.stream = mock_stream
        
        # Should not raise (stops validation after 10MB)
        await validate_file_size_during_upload(file, max_size=100 * 1024 * 1024 * 1024)  # 100GB
