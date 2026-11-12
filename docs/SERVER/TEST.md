# Server tests

The FastAPI backend test suite covers API behavior, database isolation, background tasks, media processing, uploads, and path conversion. Test counts and pass/fail results are specific to the commit and environment; this document intentionally does not claim a current result. Record the exact source SHA and pytest collection/result in release evidence.

## Safety requirements

- Use the isolated database and temporary storage supplied by the test fixtures.
- Do not point tests at a real database, production credentials, valuable local media, or a deployment storage directory.
- Keep database URLs, secrets, and environment-specific paths out of test output and committed fixtures.
- Video-list coverage must prove missing media does not remove metadata and that `GET /api/videos` performs no SQL mutations.

## Run the suite

From `server/`, install the pinned dependencies and run:

```sh
python -m pip install -r requirements.txt
python -m pytest -q -p no:cacheprovider
```

Run one file or test by passing its path/node ID, for example:

```sh
python -m pytest -q -p no:cacheprovider tests/test_video_list_api_isolation.py
```

For CI/release evidence, include Python version, dependency source, collected count, passed/failed/skipped counts, warnings, and the command's exit status. Do not copy secret values or private host paths into logs or reports.
