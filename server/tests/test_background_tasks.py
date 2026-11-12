"""Tests for Background Tasks"""
import pytest
import json
import asyncio
from pathlib import Path
from unittest.mock import AsyncMock, patch, MagicMock
from app.services.background_tasks import extract_metadata_task, generate_thumbnail_task
from app.models.video import Video
from app.models.error_log import ErrorLog


class TestBackgroundTasks:
    """Tests for background tasks"""
    
    @pytest.mark.asyncio
    async def test_extract_metadata_task_success(self, db_session, db_session_factory, test_settings, monkeypatch):
        """Test successful metadata extraction task"""
        monkeypatch.setattr("app.services.background_tasks.settings", test_settings)
        monkeypatch.setattr("app.services.background_tasks.SessionLocal", db_session_factory)
        
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
        
        # Mock metadata extraction
        mock_metadata = {
            "duration": 3600,
            "width": 1920,
            "height": 1080,
            "codec": "h264",
            "framerate": 30.0,
            "bitrate": 5000000,
            "raw_metadata": {},
        }
        
        with patch("app.services.background_tasks.extract_metadata", new_callable=AsyncMock) as mock_extract:
            mock_extract.return_value = mock_metadata
            
            await extract_metadata_task(video.id)
            
            # Wait a bit for database to sync (background tasks use different session)
            await asyncio.sleep(0.1)
            
            # Refresh video from database (need to expire and reload)
            db_session.expire_all()
            video = db_session.query(Video).filter(Video.id == video.id).first()
            
            assert video.duration == 3600
            assert video.width == 1920
            assert video.height == 1080
            assert video.video_metadata is not None
            assert video.status == "ready"
    
    @pytest.mark.asyncio
    async def test_extract_metadata_task_retry(self, db_session, db_session_factory, test_settings, monkeypatch):
        """Test metadata extraction task with retry"""
        monkeypatch.setattr("app.services.background_tasks.settings", test_settings)
        monkeypatch.setattr("app.services.background_tasks.SessionLocal", db_session_factory)
        # Set retries to 3 for this test
        test_settings.MAX_RETRIES_BACKGROUND_TASKS = 3
        
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
        
        # Mock metadata extraction to fail 2 times, then succeed
        mock_metadata = {
            "duration": 3600,
            "width": 1920,
            "height": 1080,
            "codec": "h264",
            "framerate": 30.0,
            "bitrate": 5000000,
            "raw_metadata": {},
        }
        
        call_count = 0
        
        async def mock_extract_side_effect(*args, **kwargs):
            nonlocal call_count
            call_count += 1
            if call_count < 3:
                raise Exception("Temporary error")
            return mock_metadata
        
        with patch("app.services.background_tasks.extract_metadata", side_effect=mock_extract_side_effect):
            with patch("app.services.background_tasks.asyncio.sleep", new_callable=AsyncMock):
                await extract_metadata_task(video.id)
                
                # Wait a bit for database to sync (background tasks use different session)
                await asyncio.sleep(0.1)
                
                # Refresh video from database (need to expire and reload)
                db_session.expire_all()
                video = db_session.query(Video).filter(Video.id == video.id).first()
                
                assert video.duration == 3600
                assert video.status == "ready"
                assert call_count == 3  # Should have retried 3 times
    
    @pytest.mark.asyncio
    async def test_extract_metadata_task_all_retries_fail(self, db_session, db_session_factory, test_settings, monkeypatch):
        """Test metadata extraction task with all retries failing"""
        monkeypatch.setattr("app.services.background_tasks.settings", test_settings)
        monkeypatch.setattr("app.services.background_tasks.SessionLocal", db_session_factory)
        # Set retries to 3 for this test
        test_settings.MAX_RETRIES_BACKGROUND_TASKS = 3
        
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
        
        # Mock metadata extraction to always fail
        with patch("app.services.background_tasks.extract_metadata", new_callable=AsyncMock) as mock_extract:
            mock_extract.side_effect = Exception("FFprobe failed")
            
            # Mock sleep to avoid actual delays in tests
            async def mock_sleep(delay):
                pass
            
            with patch("app.services.background_tasks.asyncio.sleep", side_effect=mock_sleep):
                await extract_metadata_task(video.id)
                
                # Wait a bit for database to sync (background tasks use different session)
                await asyncio.sleep(0.1)
                
                # Refresh video from database (need to expire and reload)
                db_session.expire_all()
                video = db_session.query(Video).filter(Video.id == video.id).first()
                
                assert video.status == "error"
                assert video.metadata_extraction_error is not None
                
                # Check error log
                error_log = db_session.query(ErrorLog).filter(
                    ErrorLog.video_id == video.id
                ).first()
                
                assert error_log is not None
                assert error_log.operation == "metadata_extraction"
    
    @pytest.mark.asyncio
    async def test_generate_thumbnail_task_success(self, db_session, db_session_factory, tmp_path, test_settings, monkeypatch):
        """Test successful thumbnail generation task"""
        monkeypatch.setattr("app.services.background_tasks.settings", test_settings)
        monkeypatch.setattr("app.services.background_tasks.SessionLocal", db_session_factory)
        
        # Create video
        video = Video(
            id="test-id",
            title="Test Video",
            filename="test.mp4",
            file_path=str(tmp_path / "test.mp4"),
            file_size=1000000,
            file_format="mp4",
            status="processing",
        )
        db_session.add(video)
        db_session.commit()
        
        # Create video file
        (tmp_path / "test.mp4").write_bytes(b"fake video")
        
        # Create thumbnail file manually
        thumbnail_path = Path(test_settings.THUMBNAILS_PATH) / f"{video.id}.jpg"
        thumbnail_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Mock thumbnail generation
        with patch("app.services.background_tasks.generate_thumbnail", new_callable=AsyncMock) as mock_generate:
            mock_generate.return_value = str(thumbnail_path)
            thumbnail_path.write_bytes(b"fake thumbnail")  # Create file after mock
            
            await generate_thumbnail_task(video.id)
            
            # Wait a bit for database to sync (background tasks use different session)
            await asyncio.sleep(0.1)
            
            # Refresh video from database (need to expire and reload)
            db_session.expire_all()
            video = db_session.query(Video).filter(Video.id == video.id).first()
            
            assert video.thumbnail_path == str(thumbnail_path)
    
    @pytest.mark.asyncio
    async def test_generate_thumbnail_task_fallback_to_default(self, db_session, db_session_factory, tmp_path, test_settings, monkeypatch):
        """Test thumbnail generation task falling back to default"""
        monkeypatch.setattr("app.services.background_tasks.settings", test_settings)
        monkeypatch.setattr("app.services.background_tasks.SessionLocal", db_session_factory)
        
        # Create default thumbnail
        default_thumbnail = Path(test_settings.DEFAULT_THUMBNAIL_PATH)
        default_thumbnail.parent.mkdir(parents=True, exist_ok=True)
        default_thumbnail.write_bytes(b"default thumbnail")
        
        # Create video
        video = Video(
            id="test-id",
            title="Test Video",
            filename="test.mp4",
            file_path=str(tmp_path / "test.mp4"),
            file_size=1000000,
            file_format="mp4",
            status="processing",
        )
        db_session.add(video)
        db_session.commit()
        
        # Mock thumbnail generation to always fail
        with patch("app.services.background_tasks.generate_thumbnail", new_callable=AsyncMock) as mock_generate:
            mock_generate.side_effect = Exception("FFmpeg failed")
            
            with patch("app.services.background_tasks.asyncio.sleep", new_callable=AsyncMock):
                await generate_thumbnail_task(video.id)
                
                # Wait a bit for database to sync (background tasks use different session)
                await asyncio.sleep(0.1)
                
                # Refresh video from database (need to expire and reload)
                db_session.expire_all()
                video = db_session.query(Video).filter(Video.id == video.id).first()
                
                # Should use default thumbnail
                assert video.thumbnail_path == str(default_thumbnail)
                
                # Check error log
                error_log = db_session.query(ErrorLog).filter(
                    ErrorLog.video_id == video.id
                ).first()
                
                assert error_log is not None
                assert error_log.operation == "thumbnail_generation"
                err_data = error_log.error_data if isinstance(error_log.error_data, dict) else json.loads(error_log.error_data)
                assert err_data["used_default"] is True
