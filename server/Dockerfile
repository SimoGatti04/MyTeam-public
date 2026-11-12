# ─────────────────────────────────────────────
# MyTeam Video Server — Dockerfile
# Base: Python 3.11 slim (Linux)
# FFmpeg installato nel container
# DB e storage montati come volumi esterni
# ─────────────────────────────────────────────

FROM python:3.11-slim

# --- Dipendenze di sistema + FFmpeg ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# --- Utente non-root per sicurezza ---
RUN groupadd -r myteam && useradd -r -g myteam -d /app myteam

WORKDIR /app

# --- Dipendenze Python prima del codice (layer cache) ---
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# --- Codice applicativo ---
COPY app/ ./app/

# --- Directory dati (montate come volumi, create solo come fallback) ---
RUN mkdir -p /app/storage/videos /app/storage/thumbnails /app/storage/qualities /app/logs \
    && chown -R myteam:myteam /app

USER myteam

# --- Health check sull'endpoint /health ---
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

EXPOSE 8000

CMD ["uvicorn", "app.main:app", \
     "--host", "0.0.0.0", \
     "--port", "8000", \
     "--timeout-keep-alive", "300", \
     "--timeout-graceful-shutdown", "30"]
