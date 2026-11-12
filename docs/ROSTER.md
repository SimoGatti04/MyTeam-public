# Contribution boundaries

This project contains a Flutter client and a service component. Keep changes scoped to the component being changed and coordinate contract changes through versioned documentation and tests.

| Component | Primary paths |
| --- | --- |
| Client application | `lib/`, `test/`, `android/`, `windows/`, `macos/`, `ios/`, `docs/APP/` |
| Service | `server/`, `docs/SERVER/` |
| Deployment configuration | Maintained and authorized separately from this client source snapshot |

Do not include credentials, private infrastructure details, local machine paths, or production data in source, documentation, tests, logs, or artifacts. The release process and its safety gates are documented in [`docs/APP/PRODUCTION-RELEASE.md`](APP/PRODUCTION-RELEASE.md).
