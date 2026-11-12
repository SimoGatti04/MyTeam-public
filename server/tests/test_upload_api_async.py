"""Tests for Upload API Endpoint - Async version"""
import pytest
import os
from pathlib import Path
from io import BytesIO
from unittest.mock import patch
from app.models.video import Video
from app.models.upload_queue import UploadQueue


class TestUploadAPI:
    """Tests for upload API endpoint"""
    
    @pytest.mark.asyncio
    async def test_upload_video_success(self, async_client, db_session, test_settings, tmp_path, monkeypatch):
        """Test successful video upload"""
        # Mock settings
        monkeypatch.setattr("app.api.routes.videos.settings", test_settings)
        monkeypatch.setattr("app.core.config.get_settings", lambda: test_settings)
        monkeypatch.setattr("app.services.video_service.settings", test_settings)
        monkeypatch.setattr("app.core.storage.settings", test_settings)
        
        # Create test video file
        video_content = b"fake video content" * 1000
        video_file = tmp_path / "test_video.mp4"
        video_file.write_bytes(video_content)
        
        # Upload video using async client
        # Read file content first
        with open(video_file, "rb") as f:
            file_content = f.read()
        
        # Use BytesIO for httpx
        files = {"file": ("test_video.mp4", BytesIO(file_content), "video/mp4")}
        data = {
            "title": "Test Video",
            "original_resolution_width": 1920,
            "original_resolution_height": 1080,
            "original_framerate": 30.0,
            "compressed_framerate": 30.0,
            "original_file_size": len(video_content),
        }
        
        try:
            response = await async_client.post("/api/videos", files=files, data=data)
        except Exception as e:
            # If there's an exception, print it for debugging
            print(f"Exception during upload: {e}")
            raise
        
        # Check response status
        if response.status_code != 200:
            print(f"Response status: {response.status_code}")
            print(f"Response text: {response.text}")
            print(f"Response headers: {response.headers}")
        
        assert response.status_code == 200
        response_data = response.json()
        
        assert response_data["title"] == "Test Video"
        assert response_data["original_resolution_width"] == 1920
        assert response_data["original_resolution_height"] == 1080
        assert response_data["original_framerate"] == 30.0
        assert response_data["compressed_framerate"] == 30.0
        assert response_data["status"] == "processing"
        
        # Verify video was saved to database
        video = db_session.query(Video).filter(Video.id == response_data["id"]).first()
        assert video is not None
        assert video.title == "Test Video"
        
        # Verify upload queue entry was created
        upload_queue = db_session.query(UploadQueue).filter(
            UploadQueue.video_id == response_data["id"]
        ).first()
        assert upload_queue is not None
        assert upload_queue.status == "completed"
        
        # Verify file was saved to disk
        assert Path(video.file_path).exists()
    
    @pytest.mark.asyncio
    async def test_upload_video_invalid_format(self, async_client):
        """Test upload with invalid video format"""
        files = {"file": ("test.txt", BytesIO(b"fake content"), "text/plain")}
        response = await async_client.post("/api/videos", files=files)
        
        assert response.status_code == 400
    
    @pytest.mark.asyncio
    async def test_upload_video_too_large(self, async_client, test_settings, monkeypatch):
        """Test upload with file too large"""
        monkeypatch.setattr("app.api.routes.videos.settings", test_settings)
        monkeypatch.setattr("app.core.config.get_settings", lambda: test_settings)
        
        # Create large file content (but small enough for test)
        large_content = b"x" * 1000  # Small for test, but we'll mock the check
        
        # Mock the validation to fail
        with patch("app.api.routes.videos.validate_file") as mock_validate:
            from fastapi import HTTPException
            mock_validate.side_effect = HTTPException(status_code=413, detail="File too large")
            
            files = {"file": ("test.mp4", BytesIO(large_content), "video/mp4")}
            headers = {"content-length": str(test_settings.MAX_UPLOAD_SIZE + 1)}
            response = await async_client.post("/api/videos", files=files, headers=headers)
            
            assert response.status_code == 413
    
    @pytest.mark.asyncio
    async def test_upload_video_path_traversal(self, async_client):
        """Test upload with path traversal in filename"""
        files = {"file": ("../../../etc/passwd", BytesIO(b"fake content"), "video/mp4")}
        response = await async_client.post("/api/videos", files=files)
        
        # Filename should be sanitized, but validation might still fail
        assert response.status_code in [400, 200]  # Either validation error or sanitized
    
    @pytest.mark.asyncio
    async def test_upload_video_without_metadata(self, async_client, db_session, test_settings, tmp_path, monkeypatch):
        """Test upload without compression metadata"""
        monkeypatch.setattr("app.api.routes.videos.settings", test_settings)
        monkeypatch.setattr("app.core.config.get_settings", lambda: test_settings)
        monkeypatch.setattr("app.services.video_service.settings", test_settings)
        monkeypatch.setattr("app.core.storage.settings", test_settings)
        
        # Create test video file
        video_content = b"fake video content" * 1000
        video_file = tmp_path / "test_video.mp4"
        video_file.write_bytes(video_content)
        
        # Upload video without metadata
        with open(video_file, "rb") as f:
            files = {"file": ("test_video.mp4", f, "video/mp4")}
            data = {"title": "Test Video"}
            response = await async_client.post("/api/videos", files=files, data=data)
        
        assert response.status_code == 200
        response_data = response.json()
        
        assert response_data["title"] == "Test Video"
        assert response_data["original_resolution_width"] is None
        assert response_data["original_resolution_height"] is None
    
    @pytest.mark.asyncio
    async def test_upload_video_missing_title(self, async_client, db_session, test_settings, tmp_path, monkeypatch):
        """Test upload without title (should use filename)"""
        monkeypatch.setattr("app.api.routes.videos.settings", test_settings)
        monkeypatch.setattr("app.core.config.get_settings", lambda: test_settings)
        monkeypatch.setattr("app.services.video_service.settings", test_settings)
        monkeypatch.setattr("app.core.storage.settings", test_settings)
        
        # Create test video file
        video_content = b"fake video content" * 1000
        video_file = tmp_path / "test_video.mp4"
        video_file.write_bytes(video_content)
        
        # Upload video without title
        with open(video_file, "rb") as f:
            files = {"file": ("test_video.mp4", f, "video/mp4")}
            response = await async_client.post("/api/videos", files=files)
        
        assert response.status_code == 200
        response_data = response.json()
        
        # Should use filename as title
        assert response_data["title"] in ["test_video.mp4", "Untitled"]
    
    @pytest.mark.asyncio
    async def test_upload_video_empty_file(self, async_client):
        """Test upload with empty file"""
        files = {"file": ("test.mp4", BytesIO(b""), "video/mp4")}
        response = await async_client.post("/api/videos", files=files)
        
        # Should still work (empty file is valid, just not useful)
        assert response.status_code in [200, 400]

