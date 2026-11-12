# QA updater A→B build pipeline

**Scope:** the manually invoked QA workflow builds Android APKs and Windows installers for isolated updater testing. It does not publish a feed, deploy infrastructure, contact production services for release, or distribute packages to users. QA signing identities and manifest trust keys are distinct from production and must never be promoted as production identities.

## Safe operation

- Use only a trusted, reviewed source ref and the repository's authorized QA workflow. The workflow must remain manual-only and fail closed when required QA signing configuration or the pinned QA trust key is absent or invalid.
- Configure QA credentials through the repository's approved secret facility. This public guide deliberately omits setting names and values. Do not place them in workflow inputs, source, logs, test output, or artifacts.
- Verify that Android A and B use the same QA application ID and signing certificate, with strictly increasing version codes. Windows A and B must retain the same installer AppId and update identity.
- Before testing an update, publish a valid QA manifest and detached signature through the separately authorized QA feed process. The client verifies exact manifest bytes, platform/channel, hashes, version monotonicity, and signature; never bypass these checks.
- Keep build artifacts separate from feed publication. Verify archive hashes and signatures before any authorized staging step; retain the exact tested bytes and record test evidence without publishing production artifacts.

## Current limits

An Actions build alone is not evidence that a QA feed exists or that an A→B update has been tested. A missing QA manifest is an expected unavailable state; it must not be mistaken for an invalid-signature pass. Windows installer shutdown/update handoff must be tested on a Windows VM, and Android data retention must be verified on an emulator or device prepared for QA.

For production procedure and identity boundaries, see [PRODUCTION-RELEASE.md](PRODUCTION-RELEASE.md) and [RELEASE-BASELINE.md](RELEASE-BASELINE.md).

## Windows in-app A→B handoff

The QA installer retains its stable AppId and per-user install location. The updater launches the downloaded installer as a detached process only after its active-task guard passes. Inno Setup uses Windows Restart Manager (`CloseApplications=yes`) to request a graceful application close and wait for locked files; it does not force-terminate the app or restart the old version (`RestartApplications=no`). Application data remains outside the installer target and is not removed by upgrade rules.

A successful static check is not evidence of a successful Windows upgrade. Retest with a fresh, monotonically versioned QA A′/B′ pair on a disposable Windows VM: upgrade A′ over A without uninstalling, then obtain B′ only through the in-app updater. Verify A′ exits gracefully, setup completes without a file-lock/retry dialog, existing test data remains, and B′ launches at the expected version. Do not publish to production.
