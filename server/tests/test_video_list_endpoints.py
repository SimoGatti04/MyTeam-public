"""Tests for video list, detail, and thumbnail endpoints"""
import pytest
from pathlib import Path
from app.models.video import Video
from app.models.player import VideoPlayer, Player
from app.models.training_type import VideoTrainingType, TrainingType
from app.models.team import VideoTeam, Team


@pytest.fixture
def video_id(db_session, test_settings):
    """Fixture providing a seeded video ID in the test database"""
    video = Video(
        id="fixture-test-video-id",
        title="Test Endpoint Video",
        filename="test_video.mp4",
        file_path="/tmp/test_video.mp4",
        file_size=1024000,
        file_format="mp4",
        status="ready",
        duration=120,
        width=1920,
        height=1080,
    )
    # Create dummy thumbnail file
    thumb_path = Path(test_settings.THUMBNAILS_PATH) / "fixture-test-video-id.jpg"
    thumb_path.parent.mkdir(parents=True, exist_ok=True)
    thumb_path.write_bytes(b"fake jpeg content")
    video.thumbnail_path = str(thumb_path)

    db_session.add(video)
    db_session.commit()
    return video.id


@pytest.mark.asyncio
async def test_get_videos_list(async_client, video_id):
    """Test GET /api/videos endpoint with pagination, search, sort, and status filter"""
    # 1. Default list
    response = await async_client.get("/api/videos", params={"page": 1, "limit": 20})
    assert response.status_code == 200
    data = response.json()
    assert data.get("total") >= 1
    assert any(item["id"] == video_id for item in data.get("items", []))

    # 2. Pagination
    response = await async_client.get("/api/videos", params={"page": 1, "limit": 5})
    assert response.status_code == 200
    assert response.json().get("limit") == 5

    # 3. Search filter
    response = await async_client.get("/api/videos", params={"search": "Endpoint"})
    assert response.status_code == 200
    data = response.json()
    assert any(item["id"] == video_id for item in data.get("items", []))

    # 4. Sort
    for sort_param in ["date_desc", "name_asc"]:
        response = await async_client.get("/api/videos", params={"sort": sort_param})
        assert response.status_code == 200

    # 5. Status filter
    response = await async_client.get("/api/videos", params={"status": "ready"})
    assert response.status_code == 200
    assert any(item["id"] == video_id for item in response.json().get("items", []))


@pytest.mark.asyncio
async def test_get_video_detail(async_client, video_id):
    """Test GET /api/videos/{id} endpoint"""
    # Success case
    response = await async_client.get(f"/api/videos/{video_id}")
    assert response.status_code == 200
    data = response.json()
    assert data.get("id") == video_id
    assert data.get("title") == "Test Endpoint Video"
    assert data.get("status") == "ready"
    assert data.get("duration") == 120
    assert data.get("width") == 1920
    assert data.get("height") == 1080

    # 404 Not Found case
    response_404 = await async_client.get("/api/videos/nonexistent-id")
    assert response_404.status_code == 404


@pytest.mark.asyncio
async def test_get_video_thumbnail(async_client, video_id):
    """Test GET /api/videos/{id}/thumbnail endpoint"""
    # Success case
    response = await async_client.get(f"/api/videos/{video_id}/thumbnail")
    assert response.status_code == 200
    assert len(response.content) > 0

    # 404 Not Found case
    response_404 = await async_client.get("/api/videos/nonexistent-id/thumbnail")
    assert response_404.status_code == 404
