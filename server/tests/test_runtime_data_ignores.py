"""Guard the default Compose bind-mount paths from source control."""

import subprocess
from pathlib import Path

import pytest

SERVER_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = SERVER_DIR.parent


@pytest.mark.parametrize(
    "relative_path",
    [
        "server/data/videos.db",
        "server/data/storage/videos/runtime-video.bin",
        "server/storage/thumbnails/runtime-thumbnail.bin",
        "server/logs/runtime.log",
    ],
)
def test_runtime_data_paths_are_git_ignored(relative_path: str) -> None:
    result = subprocess.run(
        ["git", "check-ignore", "--quiet", "--no-index", relative_path],
        cwd=REPO_ROOT,
        check=False,
    )
    assert result.returncode == 0, f"runtime data path is not ignored: {relative_path}"


def test_env_example_remains_trackable() -> None:
    result = subprocess.run(
        ["git", "check-ignore", "--quiet", "--no-index", "server/.env.example"],
        cwd=REPO_ROOT,
        check=False,
    )
    assert result.returncode == 1
