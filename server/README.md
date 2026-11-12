# MyTeam Video Server

FastAPI backend for video upload, metadata, streaming, and management. The API runs on port `8000` by default and can use SQLite for a single-node setup or PostgreSQL for deployments that provide the expected database secret and network service.

## Requirements

- Python 3.11 or 3.12
- FFmpeg and FFprobe available on `PATH` (video metadata/thumbnail operations)
- Docker Compose (optional)

## Local setup

From this directory:

```sh
python -m venv .venv
# Activate the environment for your shell, then:
python -m pip install -r requirements.txt
cp .env.example .env
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Open `http://127.0.0.1:8000/docs` for the interactive API schema. Configure `DATABASE_URL` and storage settings in `.env` for a non-default local setup. Keep credentials out of source control; `.env` is ignored by Git.

## Container setup

See [DEPLOY.md](DEPLOY.md) and `docker-compose.yml`. Persistent database and media paths are host-configurable; retain backups before changing or migrating any existing data.

## Tests

```sh
python -m pip install -r requirements.txt
python -m pytest -p no:cacheprovider
```

Tests should use isolated databases and temporary storage; never point a test run at a real database or media directory.

## Configuration and API

See [`.env.example`](.env.example), [`../docs/SERVER/INDEX.md`](../docs/SERVER/INDEX.md), and [`../docs/GENERAL/API-REFERENCE.md`](../docs/GENERAL/API-REFERENCE.md).

## Licensing note

Original MyTeam-authored server source is licensed under the repository-level [GNU GPL-3.0-only](../LICENSE). Third-party dependencies retain their own licenses and notices. The native third-party binary provenance/license audit is deferred until after launch as known debt; it is not complete and this repository makes no compliance-clearance claim.
