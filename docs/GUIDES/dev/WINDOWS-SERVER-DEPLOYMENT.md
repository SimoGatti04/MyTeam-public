# Windows development and self-hosting notes

This document covers portable Windows setup for the backend. Host-specific operator procedures (firewall administration, remote access, and production cutover) belong in the deployment owner's private runbook, not this public guide.

## Prerequisites

- Windows 10/11 or a supported Windows Server release
- Python 3.11 or 3.12
- FFmpeg and FFprobe installed and available on `PATH`
- PowerShell

## Install and run locally

From the repository's `server` directory:

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
Copy-Item .env.example .env
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Use `http://127.0.0.1:8000/health` for a local health check and `http://127.0.0.1:8000/docs` for the API schema. Configure FFmpeg paths and storage in `.env` as needed; keep secrets out of source control.

## Run tests

```powershell
python -m pip install -r requirements.txt
python -m pytest -p no:cacheprovider
```

Tests must use isolated database and temporary storage fixtures. Never run tests against a valuable local or production database/media directory.

## Container deployment

Use the portable Compose instructions in [`../../../server/DEPLOY.md`](../../../server/DEPLOY.md). Choose a persistent data directory, restrict network exposure, and use a tested backup/restore plan. This document intentionally omits host-specific administration and remote-access procedures.
