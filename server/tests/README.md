# Test Suite

Questa directory contiene la suite di test completa per il server.

## Struttura

```
tests/
├── conftest.py              # Fixtures e configurazione pytest
├── test_file_validation.py  # Test per file validation
├── test_video_service.py    # Test per Video Service
├── test_upload_queue_service.py  # Test per Upload Queue Service
├── test_metadata_service.py       # Test per Metadata Service
├── test_thumbnail_service.py      # Test per Thumbnail Service
├── test_background_tasks.py       # Test per Background Tasks
├── test_upload_api.py             # Test per Upload API Endpoint
└── test_edge_cases.py             # Test per casi edge e error handling
```

## Setup

1. Installa le dipendenze di test:
```bash
pip install -r requirements.txt
```

2. Esegui i test:
```bash
pytest
```

3. Esegui test specifici:
```bash
pytest tests/test_file_validation.py
pytest tests/test_video_service.py -v
```

4. Esegui test con coverage:
```bash
pytest --cov=app --cov-report=html
```

## Tipi di Test

### Unit Tests
- Test per singoli componenti isolati
- Mock di dipendenze esterne (FFmpeg, FFprobe)
- Test veloci e deterministici

### Integration Tests
- Test per flussi completi (es: upload API)
- Database in-memory per test
- Temporary storage directory

### Edge Cases
- Test per casi limite
- Error handling
- Boundary conditions

## Fixtures

### `db_session`
Database session per test (in-memory SQLite)

### `test_client`
FastAPI TestClient per test API

### `test_settings`
Settings di test con temporary storage

### `sample_video_file`
File video di esempio per test

### `sample_upload_file`
UploadFile di esempio per test

## Mock

I test usano mock per:
- **FFmpeg/FFprobe**: Non richiede installazione reale
- **File system**: Temporary directories per test
- **Database**: In-memory SQLite

## Coverage Goals

- **Services**: > 90%
- **API Endpoints**: > 85%
- **Utilities**: > 95%

## Running Tests

```bash
# Tutti i test
pytest

# Test specifici
pytest tests/test_upload_api.py

# Test con verbose output
pytest -v

# Test con coverage
pytest --cov=app --cov-report=term-missing

# Test veloci (skip slow tests)
pytest -m "not slow"

# Solo unit tests
pytest -m unit

# Solo integration tests
pytest -m integration
```

## Continuous Integration

I test possono essere eseguiti in CI/CD:
```yaml
# Example GitHub Actions
- name: Run tests
  run: |
    pip install -r requirements.txt
    pytest --cov=app --cov-report=xml
```
