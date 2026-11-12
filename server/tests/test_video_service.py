"""Tests for Video Service"""
import pytest
import os
from pathlib import Path
from fastapi import UploadFile, HTTPException
from io import BytesIO
from app.services.video_service import VideoService
from app.models.video import Video


class TestVideoService:
    """Tests for VideoService"""
    
    def test_save_video_basic(self, db_session, test_settings, monkeypatch):
        """Test basic video save"""
        # Mock settings
        monkeypatch.setattr("app.services.video_service.settings", test_settings)
        monkeypatch.setattr("app.core.config.get_settings", lambda: test_settings)
        
        service = VideoService(db_session)
        
        file = UploadFile(
            filename="test.mp4",
            file=BytesIO(b"fake video content"),
            headers={"content-type": "video/mp4"}
        )
        
        video = service.save_video(
            file=file,
            title="Test Video",
            original_resolution_width=1920,
            original_resolution_height=1080,
            original_framerate=30.0,
            compressed_framerate=30.0,
            original_file_size=1000000,
        )
        
        assert video is not None
        assert video.title == "Test Video"
        assert video.status == "processing"
        assert video.original_resolution_width == 1920
        assert video.original_resolution_height == 1080
        assert video.original_framerate == 30.0
        assert video.compressed_framerate == 30.0
        assert video.original_file_size == 1000000
        assert video.file_format == "mp4"
    
    def test_save_video_without_metadata(self, db_session, test_settings, monkeypatch):
        """Test video save without compression metadata"""
        monkeypatch.setattr("app.services.video_service.settings", test_settings)
        monkeypatch.setattr("app.core.config.get_settings", lambda: test_settings)
        
        service = VideoService(db_session)
        
        file = UploadFile(
            filename="test.mp4",
            file=BytesIO(b"fake video content"),
            headers={"content-type": "video/mp4"}
        )
        
        video = service.save_video(
            file=file,
            title="Test Video",
        )
        
        assert video is not None
        assert video.title == "Test Video"
        assert video.original_resolution_width is None
        assert video.original_resolution_height is None
    
    def test_update_video_file_size(self, db_session, test_settings, monkeypatch):
        """Test update video file size"""
        monkeypatch.setattr("app.services.video_service.settings", test_settings)
        monkeypatch.setattr("app.core.config.get_settings", lambda: test_settings)
        
        service = VideoService(db_session)
        
        # Create video
        video = Video(
            id="test-id",
            title="Test Video",
            filename="test.mp4",
            file_path="/tmp/test.mp4",
            file_size=0,
            file_format="mp4",
            original_file_size=1000000,
        )
        db_session.add(video)
        db_session.commit()
        
        # Update file size
        updated_video = service.update_video_file_size(video.id, 500000)
        
        assert updated_video.file_size == 500000
        assert updated_video.compression_ratio == 0.5  # 50% compression
    
    def test_update_video_metadata(self, db_session, test_settings, monkeypatch):
        """Test update video metadata"""
        monkeypatch.setattr("app.services.video_service.settings", test_settings)
        monkeypatch.setattr("app.core.config.get_settings", lambda: test_settings)
        
        service = VideoService(db_session)
        
        # Create video
        video = Video(
            id="test-id",
            title="Test Video",
            filename="test.mp4",
            file_path="/tmp/test.mp4",
            file_size=1000000,
            file_format="mp4",
            status="processing",
        )
        db_session.add(video)
        db_session.commit()
        
        # Update metadata
        updated_video = service.update_video_metadata(
            video_id=video.id,
            duration=3600,
            width=1920,
            height=1080,
            video_metadata={"codec": "h264", "bitrate": 5000000},
        )
        
        assert updated_video.duration == 3600
        assert updated_video.width == 1920
        assert updated_video.height == 1080
        assert updated_video.video_metadata == {"codec": "h264", "bitrate": 5000000}
        assert updated_video.status == "ready"  # Status updated to ready
    
    def test_update_video_thumbnail(self, db_session, test_settings, monkeypatch):
        """Test update video thumbnail"""
        monkeypatch.setattr("app.services.video_service.settings", test_settings)
        monkeypatch.setattr("app.core.config.get_settings", lambda: test_settings)
        
        service = VideoService(db_session)
        
        # Create video
        video = Video(
            id="test-id",
            title="Test Video",
            filename="test.mp4",
            file_path="/tmp/test.mp4",
            file_size=1000000,
            file_format="mp4",
        )
        db_session.add(video)
        db_session.commit()
        
        # Update thumbnail
        updated_video = service.update_video_thumbnail(video.id, "/thumbnails/test.jpg")
        
        assert updated_video.thumbnail_path == "/thumbnails/test.jpg"
    
    def test_update_video_metadata_error(self, db_session, test_settings, monkeypatch):
        """Test update video metadata error"""
        monkeypatch.setattr("app.services.video_service.settings", test_settings)
        monkeypatch.setattr("app.core.config.get_settings", lambda: test_settings)
        
        service = VideoService(db_session)
        
        # Create video
        video = Video(
            id="test-id",
            title="Test Video",
            filename="test.mp4",
            file_path="/tmp/test.mp4",
            file_size=1000000,
            file_format="mp4",
            status="processing",
        )
        db_session.add(video)
        db_session.commit()
        
        # Update with error
        error_data = {"error": "FFprobe failed", "retries": 5}
        updated_video = service.update_video_metadata_error(video.id, error_data)
        
        assert updated_video.metadata_extraction_error is not None
        assert updated_video.status == "error"
    
    def test_update_video_not_found(self, db_session, test_settings, monkeypatch):
        """Test update video not found"""
        monkeypatch.setattr("app.services.video_service.settings", test_settings)
        monkeypatch.setattr("app.core.config.get_settings", lambda: test_settings)
        
        service = VideoService(db_session)
        
        with pytest.raises(HTTPException) as exc_info:
            service.update_video_file_size("non-existent-id", 1000)
        
        assert exc_info.value.status_code == 404
