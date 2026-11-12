"""Pytest configuration and fixtures"""
import os
import sys

# Pytest bootstrap isolation guard:
# Force DATABASE_URL to in-memory SQLite before any application modules are imported.
# This guarantees fail-closed isolation: no test setup, app import, or runner
# can ever connect to an external or production database.
os.environ["DATABASE_URL"] = "sqlite:///:memory:"

import pytest
import tempfile
import shutil
from pathlib import Path
from sqlalchemy import create_engine, event
from sqlalchemy.engine import Engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient
from fastapi import FastAPI
import uuid


def _reject_non_sqlite_connections(dialect, connection_record, cargs, cparams):
    if dialect.name != "sqlite":
        raise AssertionError(f"tests must not connect to {dialect.name} databases")


event.listen(Engine, "do_connect", _reject_non_sqlite_connections)

# Test database URL (in-memory SQLite)
TEST_DATABASE_URL = "sqlite:///:memory:"

# Test storage directory
TEST_STORAGE_DIR = None

@pytest.fixture(scope="session", autouse=True)
def setup_test_environment():
    """Setup test environment (runs once per test session)"""
    global TEST_STORAGE_DIR

    # Create temporary storage directory
    TEST_STORAGE_DIR = tempfile.mkdtemp(prefix="mpteam_test_")

    # Create subdirectories
    Path(TEST_STORAGE_DIR, "videos").mkdir(parents=True, exist_ok=True)
    Path(TEST_STORAGE_DIR, "thumbnails").mkdir(parents=True, exist_ok=True)
    Path(TEST_STORAGE_DIR, "qualities").mkdir(parents=True, exist_ok=True)

    yield

    # Cleanup
    if TEST_STORAGE_DIR and os.path.exists(TEST_STORAGE_DIR):
        shutil.rmtree(TEST_STORAGE_DIR)

@pytest.fixture
def test_settings(setup_test_environment):
    """Test settings with temporary storage"""
    global TEST_STORAGE_DIR
    from app.core.config import Settings

    return Settings(
        DATABASE_URL=TEST_DATABASE_URL,
        STORAGE_PATH=TEST_STORAGE_DIR,
        VIDEOS_PATH=str(Path(TEST_STORAGE_DIR, "videos")),
        THUMBNAILS_PATH=str(Path(TEST_STORAGE_DIR, "thumbnails")),
        QUALITIES_PATH=str(Path(TEST_STORAGE_DIR, "qualities")),
        FFMPEG_PATH="/usr/bin/ffmpeg",
        FFPROBE_PATH="/usr/bin/ffprobe",
        MAX_UPLOAD_SIZE=53687091200,  # 50GB
        MAX_CONCURRENT_UPLOADS=10,
        UPLOAD_TIMEOUT=86400,
        MAX_RETRIES_BACKGROUND_TASKS=1,
        METADATA_EXTRACTION_TIMEOUT=3600,
        THUMBNAIL_GENERATION_TIMEOUT=600,
        DEFAULT_THUMBNAIL_PATH=str(Path(TEST_STORAGE_DIR, "default_thumbnail.jpg")),
        DEBUG=True,
    )

@pytest.fixture(scope="session")
def _shared_test_engine():
    """Create session-wide test database engine with StaticPool"""
    from app.core.database import Base
    from app.models import (  # noqa: F401
        video,
        upload_queue,
        error_log,
        player,
        training_type,
        team,
        note,
    )

    engine = create_engine(
        TEST_DATABASE_URL,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
        echo=False
    )
    Base.metadata.create_all(bind=engine)
    yield engine
    Base.metadata.drop_all(bind=engine)

@pytest.fixture
def db_engine(_shared_test_engine):
    """Provide test database engine for each test, cleaning tables between tests"""
    from app.core.database import Base
    Base.metadata.create_all(bind=_shared_test_engine)
    yield _shared_test_engine
    with _shared_test_engine.connect() as conn:
        for table in reversed(Base.metadata.sorted_tables):
            conn.execute(table.delete())
        conn.commit()

@pytest.fixture
def db_session_factory(db_engine):
    """Create test session factory bound to shared in-memory engine"""
    return sessionmaker(autocommit=False, autoflush=False, bind=db_engine)

@pytest.fixture
def db_session(db_session_factory):
    """Create test database session"""
    session = db_session_factory()
    try:
        yield session
    finally:
        session.close()

@pytest.fixture
def mock_db_session(monkeypatch, db_session):
    """Mock database session dependency"""
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    monkeypatch.setattr("app.core.database.get_db", override_get_db)
    return db_session

@pytest.fixture
def test_app(mock_db_session, db_session_factory, test_settings, monkeypatch):
    """Create test FastAPI app"""
    # Mock settings before importing app
    monkeypatch.setattr("app.core.config.get_settings", lambda: test_settings)
    monkeypatch.setattr("app.core.config.Settings", lambda **kwargs: test_settings)
    monkeypatch.setattr("app.api.routes.videos.settings", test_settings)
    monkeypatch.setattr("app.services.video_service.settings", test_settings)
    monkeypatch.setattr("app.core.storage.settings", test_settings)
    monkeypatch.setattr("app.services.background_tasks.SessionLocal", db_session_factory)
    monkeypatch.setattr("app.services.background_tasks.settings", test_settings)

    # Create a new app instance for testing
    from fastapi import FastAPI
    from fastapi.middleware.cors import CORSMiddleware
    from app.core.database import Base
    from app.core.config import init_storage_directories
    from app.api.routes import videos

    # Initialize storage with test settings
    init_storage_directories(test_settings)

    # Create test app
    test_app = FastAPI(title="MyTeam Video Server Test")
    test_app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Override database dependency
    def override_get_db():
        try:
            yield mock_db_session
        finally:
            pass

    # Override the exact dependency object captured by the videos route at import time.
    test_app.dependency_overrides[videos.get_db] = override_get_db

    # Register routes
    test_app.include_router(videos.router, tags=["videos"])

    return test_app

@pytest.fixture
async def async_client(test_app):
    """Create async test client using httpx"""
    from httpx import ASGITransport, AsyncClient

    transport = ASGITransport(app=test_app)
    async_client = AsyncClient(transport=transport, base_url="http://testserver")

    yield async_client

    await async_client.aclose()

@pytest.fixture
def test_client(test_app):
    """Create sync test client - simpler approach using httpx Client"""
    from httpx import Client

    client = Client(base_url="http://testserver")
    yield client
    client.close()
