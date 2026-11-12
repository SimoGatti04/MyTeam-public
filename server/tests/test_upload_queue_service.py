"""Tests for Upload Queue Service"""
import pytest
from datetime import datetime
from app.services.upload_queue_service import UploadQueueService
from app.models.upload_queue import UploadQueue


class TestUploadQueueService:
    """Tests for UploadQueueService"""
    
    def test_create_upload_queue_entry(self, db_session):
        """Test create upload queue entry"""
        service = UploadQueueService(db_session)
        
        entry = service.create_upload_queue_entry(
            filename="test.mp4",
            file_path="/tmp/test.mp4",
            file_size=1000000,
        )
        
        assert entry is not None
        assert entry.local_filename == "test.mp4"
        assert entry.remote_filename == "test.mp4"
        assert entry.file_path == "/tmp/test.mp4"
        assert entry.total_bytes == 1000000
        assert entry.uploaded_bytes == 0
        assert entry.status == "queued"
        assert entry.progress == 0.0
    
    def test_update_upload_queue_status(self, db_session):
        """Test update upload queue status"""
        service = UploadQueueService(db_session)
        
        # Create entry
        entry = service.create_upload_queue_entry(
            filename="test.mp4",
            file_path="/tmp/test.mp4",
            file_size=1000000,
        )
        
        # Update status
        updated = service.update_upload_queue_status(
            upload_id=entry.id,
            status="processing",
            video_id="video-id-123",
            progress=0.5,
        )
        
        assert updated.status == "processing"
        assert updated.video_id == "video-id-123"
        assert updated.progress == 0.5
        assert updated.started_at is not None
    
    def test_update_upload_progress(self, db_session):
        """Test update upload progress"""
        service = UploadQueueService(db_session)
        
        # Create entry
        entry = service.create_upload_queue_entry(
            filename="test.mp4",
            file_path="/tmp/test.mp4",
            file_size=1000000,
        )
        
        # Update progress
        updated = service.update_upload_progress(
            upload_id=entry.id,
            uploaded_bytes=500000,
        )
        
        assert updated.uploaded_bytes == 500000
        assert updated.progress == 0.5
    
    def test_update_upload_queue_status_completed(self, db_session):
        """Test update upload queue status to completed"""
        service = UploadQueueService(db_session)
        
        # Create entry
        entry = service.create_upload_queue_entry(
            filename="test.mp4",
            file_path="/tmp/test.mp4",
            file_size=1000000,
        )
        
        # Update to completed
        updated = service.update_upload_queue_status(
            upload_id=entry.id,
            status="completed",
            progress=1.0,
        )
        
        assert updated.status == "completed"
        assert updated.progress == 1.0
        assert updated.completed_at is not None
    
    def test_update_upload_queue_status_error(self, db_session):
        """Test update upload queue status to error"""
        service = UploadQueueService(db_session)
        
        # Create entry
        entry = service.create_upload_queue_entry(
            filename="test.mp4",
            file_path="/tmp/test.mp4",
            file_size=1000000,
        )
        
        # Update to error
        updated = service.update_upload_queue_status(
            upload_id=entry.id,
            status="error",
            error_message="Upload failed",
        )
        
        assert updated.status == "error"
        assert updated.error_message == "Upload failed"
        assert updated.completed_at is not None
    
    def test_get_upload_queue_entry(self, db_session):
        """Test get upload queue entry"""
        service = UploadQueueService(db_session)
        
        # Create entry
        entry = service.create_upload_queue_entry(
            filename="test.mp4",
            file_path="/tmp/test.mp4",
            file_size=1000000,
        )
        
        # Get entry
        retrieved = service.get_upload_queue_entry(entry.id)
        
        assert retrieved.id == entry.id
        assert retrieved.local_filename == "test.mp4"
    
    def test_get_upload_queue_entry_not_found(self, db_session):
        """Test get upload queue entry not found"""
        service = UploadQueueService(db_session)
        
        from fastapi import HTTPException
        
        with pytest.raises(HTTPException) as exc_info:
            service.get_upload_queue_entry("non-existent-id")
        
        assert exc_info.value.status_code == 404
    
    def test_get_active_uploads_count(self, db_session):
        """Test get active uploads count"""
        service = UploadQueueService(db_session)
        
        # Initially no active uploads
        assert service.get_active_uploads_count() == 0
        
        # Create entries with different statuses
        service.create_upload_queue_entry("test1.mp4", "/tmp/test1.mp4", 1000000)
        entry2 = service.create_upload_queue_entry("test2.mp4", "/tmp/test2.mp4", 1000000)
        entry3 = service.create_upload_queue_entry("test3.mp4", "/tmp/test3.mp4", 1000000)
        
        # Set some to processing
        service.update_upload_queue_status(entry2.id, "processing")
        service.update_upload_queue_status(entry3.id, "processing")
        
        # Should have 2 active uploads
        assert service.get_active_uploads_count() == 2
