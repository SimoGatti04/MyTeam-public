"""Portable behavior tests for the legacy Windows media-path converter."""
from scripts.fix_db_paths import fix_path


def test_maps_windows_profile_path_without_hard_coded_account():
    assert fix_path(
        r"D:\Users\example-user\Documents\MyTeam\server\storage\videos\clip.mp4"
    ) == "/app/storage/videos/clip.mp4"


def test_maps_forward_slash_windows_profile_path():
    assert fix_path(
        "E:/Users/example-user/Documents/MyTeam/server/storage/thumbnails/clip.jpg"
    ) == "/app/storage/thumbnails/clip.jpg"


def test_leaves_unrelated_media_path_root_unchanged():
    assert fix_path("/mnt/media/videos/clip.mp4") == "/mnt/media/videos/clip.mp4"
