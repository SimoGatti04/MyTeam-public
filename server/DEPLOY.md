# Self-hosting the MyTeam Video Server

This guide describes a portable, self-managed Docker Compose deployment. It does not specify a particular registry, host, ingress provider, or infrastructure. Choose and secure those independently.

## Build and configure

From the repository's `server/` directory:

```sh
cp .env.example .env
# Edit .env for the deployment. Never commit credentials.
docker compose build
docker compose up -d
```

The default Compose setup uses SQLite and publishes the service on the loopback interface at port `8000`. Its default CORS origin, `http://localhost:3000`, is for local development only. Before any real deployment, set `CORS_ORIGINS` in `.env` to the exact HTTPS origins of the authorized web clients; do not rely on the sample local origin or use a wildcard. Set `MYTEAM_BIND_ADDRESS` and `MYTEAM_HTTP_PORT` in `.env` if a trusted reverse proxy or a different local port requires another binding. Do not expose the application directly to the public internet without an appropriate authenticated ingress and TLS configuration.

`MYTEAM_DATA_DIR` selects the host directory for the database, media, and logs. The default is a project-local `data/` directory, which is excluded from Git and the Docker build context. If you choose another path inside the source tree, add it to both ignore files; preferably keep persistent data outside the source/build context. Create the database file and storage directories before starting Compose, monitor free space, and maintain tested backups. Never point an experimental deployment or test run at an existing production data directory. For the defaults, run `mkdir -p data/storage/videos data/storage/thumbnails data/storage/qualities data/logs && touch data/videos.db` from `server/`.

The container runs as the non-root `myteam` user. Bind mounts use host filesystem ownership and permissions, overriding the image directory ownership. On Linux, determine the numeric UID/GID of `myteam` in the built image (for example, with `docker compose run --rm --no-deps --entrypoint id myteam-server myteam`) and grant that UID/GID write access to the data directory and database file before starting the service. Keep permissions as restrictive as your deployment permits; do not use world-writable permissions as a workaround. A `touch` command alone does not ensure the container can write.

Set `MYTEAM_SERVER_IMAGE` to an image reference from a registry you control, or keep the local build default. Use immutable image tags/digests for controlled releases rather than relying on `latest`.

## Optional PostgreSQL

The application supports the existing Docker-secret contract: mount the database password as `/run/secrets/myteam_db_password`. When that secret exists, the application uses the PostgreSQL service name `myteam_postgres` on port `5432`; attach the server container to a Docker network where that service name resolves. `docker-compose.postgres.example.yml` is an opt-in overlay example. Set `MYTEAM_DB_PASSWORD_FILE` to a secret file held outside the repository and `MYTEAM_BACKEND_NETWORK` to the deployment's Docker network name before using the overlay. Do not put the password in `.env`, a Compose file, command arguments, or logs.

SQLite and PostgreSQL deployments must use persistent storage and a tested backup/restore procedure. Schema scripts under `scripts/` are maintenance tools: inspect their effects and take a verified backup before applying one to valuable data.

## Health and API

The container health check calls `/health` locally. The API schema is available at `/docs` when enabled by the application configuration. Set `CORS_ORIGINS` to the exact web-client origins required by your deployment; avoid a wildcard for a public service.

## Data-preserving updates

1. Review release notes and the exact source revision/image.
2. Verify a restorable database and media backup.
3. Deploy to a separate test environment and verify health, uploads, reads, and media playback.
4. Promote only after the owner-approved QA and release gates pass.
5. For rollback, redeploy the previously approved immutable image and restore data only from a verified backup when required; do not delete or overwrite data as a routine rollback step.
