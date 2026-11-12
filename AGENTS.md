# MyTeam agent entry

Start with this router, then consult the task-specific source of truth; do not rely on chat history for release state.

## Production releases

For any release, updater, signing, feed, or release-artifact task, **read and follow [`docs/APP/PRODUCTION-RELEASE.md`](docs/APP/PRODUCTION-RELEASE.md) first**. It is the canonical, version-controlled procedure and includes the current HOLD ledger, roles, gates, and the current client/deployment interfaces. Read [`docs/APP/RELEASE-BASELINE.md`](docs/APP/RELEASE-BASELINE.md) for adopted identities. The RC runbook is historical workflow-specific detail, not an alternate procedure.

- CLIENT agents: app identity, build/signing guards, updater, validation and candidate artifacts only.
- Deployment operators: production service/feed storage, routes, publishing and rollback only; use the separately maintained deployment procedure.
- Only the owner/release operator authorizes production publication with a separate exact-version GO. A build, test, draft archive, or generic “proceed” is not GO.
- Never place credentials/private keys in Git, command arguments, logs, chat, or release evidence. Never promote QA identity/artifacts as production.

## Repository navigation

- Root [`README.md`](README.md): project overview and documentation links.
- [`docs/README.md`](docs/README.md): full documentation map.
- [`docs/APP/INDEX.md`](docs/APP/INDEX.md): Flutter/client documentation index.
- `.github/workflows/`: CI and manually triggered candidate workflows.
- `tool/`: release and signing validation utilities. `manifest_signature_verifier.dart` is the pure-Dart verifier shared by Flutter and the CLI.

Before editing, inspect `git status --short --branch`, current branch/HEAD, relevant code/tests/docs and local changes. Keep edits inside the assigned worktree, run the narrow relevant tests, report actual evidence and limits, and do not publish/deploy unless separately authorized.
