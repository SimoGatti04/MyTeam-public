"""Tests for GET /api/videos non-destructive behavior and isolation"""
import ast
import inspect

import pytest
from pathlib import Path
from sqlalchemy import event
from app.models.video import Video
from app.api.routes.videos import list_videos
from app.models.player import Player, VideoPlayer

class TestVideoListApiIsolation:
    """Test non-destructive behavior and contract of GET /api/videos"""

    def test_list_endpoint_has_no_database_mutator_calls(self):
        """Release gate: GET must not regain implicit DB deletion/commit behavior.

        The behavioral SQL-listener tests below complement this narrow source guard.
        """
        function_ast = ast.parse(inspect.getsource(list_videos))
        mutators = {"delete", "commit", "flush"}
        violations = [
            node.func.attr
            for node in ast.walk(function_ast)
            if isinstance(node, ast.Call)
            and isinstance(node.func, ast.Attribute)
            and isinstance(node.func.value, ast.Name)
            and node.func.value.id == "db"
            and node.func.attr in mutators
        ]
        assert violations == [], f"GET /api/videos contains DB mutators: {violations}"

    @pytest.mark.asyncio
    async def test_list_videos_does_not_delete_missing_file_records(
        self, async_client, db_session, test_settings, monkeypatch
    ):
        """Verify that GET /api/videos does NOT delete records whose files are missing from storage."""
        monkeypatch.setattr("app.api.routes.videos.settings", test_settings)

        # Create video record pointing to non-existent file
        v_missing = Video(
            id="test-missing-file-id",
            title="Video With Missing File",
            filename="missing_file.mp4",
            file_path="storage/videos/missing_file.mp4",
            file_size=1024,
            file_format="mp4",
            status="ready",
        )
        db_session.add(v_missing)
        db_session.commit()

        # Ensure file truly does not exist on disk
        target_path = Path(test_settings.VIDEOS_PATH) / "missing_file.mp4"
        if target_path.exists():
            target_path.unlink()

        # Call GET /api/videos
        response = await async_client.get("/api/videos")
        assert response.status_code == 200
        data = response.json()

        # Record must still be present in database
        db_session.expire_all()
        video_in_db = db_session.query(Video).filter(Video.id == "test-missing-file-id").first()
        assert video_in_db is not None
        assert video_in_db.title == "Video With Missing File"

        # Record must be visible in items
        item_ids = [item["id"] for item in data["items"]]
        assert "test-missing-file-id" in item_ids
        assert data["total"] >= 1

    @pytest.mark.asyncio
    async def test_list_videos_does_not_delete_empty_file_path_records(
        self, async_client, db_session, test_settings, monkeypatch
    ):
        """Verify that GET /api/videos does NOT delete records with file_path=''.
        
        Note: The Video model defines `file_path = Column(String(500), nullable=False)`.
        Therefore NULL is not permitted by schema definition, but empty string '' is valid
        and must be preserved without deletion or errors.
        """
        monkeypatch.setattr("app.api.routes.videos.settings", test_settings)

        v_empty_path = Video(
            id="test-empty-path-id",
            title="Video With Empty File Path",
            filename="empty_path.mp4",
            file_path="",  # Empty string (not NULL, as schema is nullable=False)
            file_size=0,
            file_format="mp4",
            status="processing",
        )
        db_session.add(v_empty_path)
        db_session.commit()

        response = await async_client.get("/api/videos")
        assert response.status_code == 200
        data = response.json()

        db_session.expire_all()
        video_in_db = db_session.query(Video).filter(Video.id == "test-empty-path-id").first()
        assert video_in_db is not None
        assert video_in_db.id == "test-empty-path-id"
        assert video_in_db.file_path == ""

        item_ids = [item["id"] for item in data["items"]]
        assert "test-empty-path-id" in item_ids

    @pytest.mark.asyncio
    async def test_list_videos_when_storage_unavailable(
        self, async_client, db_session, test_settings, monkeypatch
    ):
        """Verify that records remain visible even when storage mount is unmounted / non-existent."""
        monkeypatch.setattr("app.api.routes.videos.settings", test_settings)

        v1 = Video(
            id="test-storage-unavail-id",
            title="Video During Storage Outage",
            filename="outage.mp4",
            file_path="storage/videos/outage.mp4",
            file_size=2048,
            file_format="mp4",
            status="ready",
        )
        db_session.add(v1)
        db_session.commit()

        # Simulate storage path completely inaccessible or non-existent
        fake_unmounted_path = "/non_existent_unmounted_storage_dir/videos"
        monkeypatch.setattr(test_settings, "VIDEOS_PATH", fake_unmounted_path)

        response = await async_client.get("/api/videos")
        assert response.status_code == 200
        data = response.json()

        db_session.expire_all()
        video_in_db = db_session.query(Video).filter(Video.id == "test-storage-unavail-id").first()
        assert video_in_db is not None

        item_ids = [item["id"] for item in data["items"]]
        assert "test-storage-unavail-id" in item_ids
        assert data["total"] >= 1

    @pytest.mark.asyncio
    async def test_list_videos_no_sql_mutations(
        self, async_client, db_session, test_settings, monkeypatch
    ):
        """Verify via SQLAlchemy listener on db_session.bind (actual engine used by test)
        that GET /api/videos emits NO INSERT, UPDATE, or DELETE, and demonstrates that
        it actually executes SELECT queries.
        """
        monkeypatch.setattr("app.api.routes.videos.settings", test_settings)

        v1 = Video(
            id="test-readonly-id",
            title="Readonly Check Video",
            filename="readonly.mp4",
            file_path="storage/videos/readonly.mp4",
            file_size=5000,
            file_format="mp4",
            status="ready",
        )
        db_session.add(v1)
        db_session.commit()

        # Bind listener specifically to the engine actually driving db_session
        target_engine = db_session.bind
        assert target_engine is not None, "db_session must have an active bound engine"

        statements = []
        def receive_before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
            statements.append(statement.strip())

        event.listen(target_engine, "before_cursor_execute", receive_before_cursor_execute)

        try:
            response = await async_client.get("/api/videos?page=1&limit=10")
            assert response.status_code == 200
        finally:
            event.remove(target_engine, "before_cursor_execute", receive_before_cursor_execute)

        # 1. Verify that the listener actually observed queries (not a no-op listener)
        assert len(statements) > 0, "Listener should have captured SQL statements executed during GET /api/videos"
        select_statements = [s for s in statements if s.upper().startswith("SELECT")]
        assert len(select_statements) >= 1, f"Expected at least one SELECT query, observed: {statements}"

        # 2. Verify that NO mutating SQL statements (DELETE, UPDATE, INSERT) were executed
        mutation_keywords = ["DELETE", "UPDATE", "INSERT"]
        mutations = [
            s for s in statements
            if any(s.upper().startswith(kw) for kw in mutation_keywords)
        ]
        assert len(mutations) == 0, f"Expected no SQL mutations, but got: {mutations}"

    @pytest.mark.asyncio
    async def test_list_videos_pagination_and_total_consistency(
        self, async_client, db_session, test_settings, monkeypatch
    ):
        """Verify pagination consistency: total reflects total matching records across all pages,
        with exact counts and filters tested.
        """
        monkeypatch.setattr("app.api.routes.videos.settings", test_settings)

        # Clean any prior videos in test session to verify exact counts
        db_session.query(Video).delete()
        db_session.commit()

        # Create 5 videos: 3 matching 'Alpha', 2 matching 'Beta'
        for i in range(3):
            v = Video(
                id=f"test-vid-alpha-{i}",
                title=f"Alpha Video {i:02d}",
                filename=f"alpha_{i:02d}.mp4",
                file_path=f"storage/videos/alpha_{i:02d}.mp4",
                file_size=1000 * (i + 1),
                file_format="mp4",
                status="ready",
            )
            db_session.add(v)

        for j in range(2):
            v = Video(
                id=f"test-vid-beta-{j}",
                title=f"Beta Video {j:02d}",
                filename=f"beta_{j:02d}.mp4",
                file_path=f"storage/videos/beta_{j:02d}.mp4",
                file_size=2000 * (j + 1),
                file_format="mp4",
                status="processing",
            )
            db_session.add(v)
        db_session.commit()

        # 1. Unfiltered list: exact total 5
        res_all = await async_client.get("/api/videos?page=1&limit=2&sort=name_asc")
        assert res_all.status_code == 200
        d_all = res_all.json()
        assert d_all["total"] == 5
        assert len(d_all["items"]) == 2
        assert d_all["page"] == 1
        assert d_all["limit"] == 2

        # Page 2: exact total 5, 2 items
        res_p2 = await async_client.get("/api/videos?page=2&limit=2&sort=name_asc")
        assert res_p2.status_code == 200
        d_p2 = res_p2.json()
        assert d_p2["total"] == 5
        assert len(d_p2["items"]) == 2

        # Page 3: exact total 5, remaining 1 item
        res_p3 = await async_client.get("/api/videos?page=3&limit=2&sort=name_asc")
        assert res_p3.status_code == 200
        d_p3 = res_p3.json()
        assert d_p3["total"] == 5
        assert len(d_p3["items"]) == 1

        # Verify disjoint pages
        p1_ids = [item["id"] for item in d_all["items"]]
        p2_ids = [item["id"] for item in d_p2["items"]]
        p3_ids = [item["id"] for item in d_p3["items"]]
        assert len(set(p1_ids + p2_ids + p3_ids)) == 5

        # 2. Filtered list by search='Alpha': exact total 3
        res_search = await async_client.get("/api/videos?search=Alpha&page=1&limit=2")
        assert res_search.status_code == 200
        d_search = res_search.json()
        assert d_search["total"] == 3
        assert len(d_search["items"]) == 2
        for item in d_search["items"]:
            assert "Alpha" in item["title"]

        # Search page 2: total 3, 1 item
        res_search_p2 = await async_client.get("/api/videos?search=Alpha&page=2&limit=2")
        assert res_search_p2.status_code == 200
        d_search_p2 = res_search_p2.json()
        assert d_search_p2["total"] == 3
        assert len(d_search_p2["items"]) == 1

        # 3. Filtered list by status='processing': exact total 2
        res_status = await async_client.get("/api/videos?status=processing")
        assert res_status.status_code == 200
        d_status = res_status.json()
        assert d_status["total"] == 2
        assert len(d_status["items"]) == 2
        for item in d_status["items"]:
            assert item["status"] == "processing"
