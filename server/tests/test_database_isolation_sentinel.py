"""Tests verifying database isolation and fail-closed test environment behavior.

These sentinels exercise the real application startup only with temporary storage
and the test-bootstrap SQLite engine. A separate control proves that a synthetic
external dialect is rejected before its DBAPI driver can be invoked.
"""
import importlib
import os
import sys

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine

import app.core.database as core_db


class TestDatabaseIsolationSentinel:
    """Sentinel regression suite for test database isolation."""

    def test_environment_database_url_is_isolated(self):
        """Pytest bootstrap replaces ambient DB configuration before app imports."""
        assert os.environ.get("DATABASE_URL") == "sqlite:///:memory:"

    def test_app_core_database_engine_is_memory_sqlite(self):
        """The process-global application engine is a test-only in-memory SQLite engine."""
        assert core_db.engine.dialect.name == "sqlite"
        assert ":memory:" in str(core_db.engine.url)

    def test_settings_database_url_is_memory_sqlite(self, test_settings):
        assert test_settings.DATABASE_URL == "sqlite:///:memory:"

    def test_db_session_fixture_is_bound_to_isolated_sqlite(self, db_session):
        bind = db_session.get_bind()
        assert bind.dialect.name == "sqlite"
        assert ":memory:" in str(bind.url)

    def test_real_app_startup_and_request_use_only_test_resources(
        self, monkeypatch, test_settings, db_session
    ):
        """Run real startup with temp resources and clean up its imported module."""
        app_main_was_loaded = "app.main" in sys.modules
        assert not app_main_was_loaded, "app.main must not import before test settings"

        import app.core.config as config
        from app.api.routes import videos

        monkeypatch.setenv(
            "DATABASE_URL",
            "postgresql://sentinel-host.invalid:5432/not-a-real-db",
        )
        monkeypatch.setattr(config, "get_settings", lambda: test_settings)
        monkeypatch.setattr(videos, "settings", test_settings)

        # Reproduce the identity split possible when a fixture patches the module
        # attribute after videos.py has already captured its dependency callable.
        def different_get_db():
            raise AssertionError("the uncaptured DB dependency must not be used")

        monkeypatch.setattr(core_db, "get_db", different_get_db)
        assert videos.get_db is not core_db.get_db

        main = None
        previous_override = None
        override_was_present = False
        try:
            main = importlib.import_module("app.main")
            monkeypatch.setattr(main, "settings", test_settings)

            def override_get_db():
                yield db_session

            # FastAPI's route Depends captured videos.get_db, not the newly
            # patched core_db.get_db object.
            override_was_present = videos.get_db in main.app.dependency_overrides
            previous_override = main.app.dependency_overrides.get(videos.get_db)
            main.app.dependency_overrides[videos.get_db] = override_get_db
            with TestClient(main.app) as client:
                response = client.get("/api/videos")

            assert response.status_code == 200
            assert os.path.commonpath(
                [test_settings.STORAGE_PATH, test_settings.VIDEOS_PATH]
            ) == test_settings.STORAGE_PATH
            assert os.path.isdir(test_settings.VIDEOS_PATH)
            assert core_db.engine.dialect.name == "sqlite"
            assert ":memory:" in str(core_db.engine.url)
        finally:
            if main is not None:
                if override_was_present:
                    main.app.dependency_overrides[videos.get_db] = previous_override
                else:
                    main.app.dependency_overrides.pop(videos.get_db, None)
            if not app_main_was_loaded:
                sys.modules.pop("app.main", None)

    def test_non_sqlite_guard_blocks_before_dbapi_connect(self, monkeypatch):
        """Positive control: the global guard rejects PostgreSQL before DBAPI/network."""
        external_url = (
            "postgresql+psycopg2://sentinel-host.invalid:5432/not-a-real-db"
        )
        engine = create_engine(external_url)
        dbapi_attempts = []

        def forbidden_dbapi_connect(*args, **kwargs):
            dbapi_attempts.append((args, kwargs))
            raise RuntimeError("DBAPI sentinel: network access must never occur")

        # SQLAlchemy has loaded the driver module during engine creation, but no
        # connection is opened. Replace its driver entry point before connect().
        try:
            monkeypatch.setattr(engine.dialect.loaded_dbapi, "connect", forbidden_dbapi_connect)
            with pytest.raises(AssertionError, match="tests must not connect to postgresql"):
                engine.connect()
            assert dbapi_attempts == []
        finally:
            monkeypatch.undo()
            engine.dispose()

    @pytest.mark.asyncio
    async def test_api_client_operates_strictly_on_isolated_db(self, async_client, db_session):
        """Verify GET /api/videos reads the test SQLite dependency, without external DB."""
        from app.models.video import Video

        test_video = Video(
            id="sentinel-isolation-video-id",
            title="Sentinel Video",
            filename="sentinel.mp4",
            file_path="/tmp/sentinel.mp4",
            file_size=1000,
            file_format="mp4",
            status="ready",
        )
        db_session.add(test_video)
        db_session.commit()

        response = await async_client.get("/api/videos")
        assert response.status_code == 200
        data = response.json()
        assert any(item["id"] == "sentinel-isolation-video-id" for item in data.get("items", []))
