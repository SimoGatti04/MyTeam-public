# MyTeam production release contract

**Authority:** canonical procedure for every production client release, first-user and later. This document supersedes release execution instructions in `RELEASE-CANDIDATE-RUNBOOK.md`; `RELEASE-BASELINE.md` remains the record of adopted identity/security decisions. Follow current source and the separately maintained deployment procedure before executing deployment steps.

**Current state (2026-11-11): HOLD — preparation only.** No production build, archive, preproduction A′→B′ verification, feed publication, deployment, or user distribution is authorized or evidenced by this document. An explicit operator GO is required separately for each production publication. A successful build or candidate archive is never a GO.

**Known post-launch debt (not a compliance clearance):** the native third-party binary provenance/license audit is deferred until after launch by owner decision. Its status remains **NOT VERIFIED**; the existing notice inventory is not a complete artifact audit. Track and complete the audit after launch. This source publication is not a production release or GO. See [THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md).

## Agent entry: read these first

1. Repository rules: [`/AGENTS.md`](../../AGENTS.md).
2. This contract (the one source of truth for releases).
3. [`RELEASE-BASELINE.md`](RELEASE-BASELINE.md) for adopted IDs, signing-key pin, and known identity gates.
4. [`RELEASE-CANDIDATE-RUNBOOK.md`](RELEASE-CANDIDATE-RUNBOOK.md) only as historical workflow-specific notes; it is superseded for procedure.
5. Client implementation: `android/app/build.gradle*`, `windows/installer/MyTeam-Setup.iss`, `lib/core/services/updater/updater_channel_config.dart`, `lib/core/services/updater/release_key_pin.dart`, `tool/release_candidate.dart`, `tool/sign_manifest.dart`, `lib/core/services/updater/manifest_signature_verifier.dart`, `.github/workflows/release-candidate.yml`.
6. Deployment handoff: the release operator follows the separately maintained, currently reviewed deployment procedure. Client documentation is not evidence of live deployment state.

**Role split:** client maintainers own identities/build/signing/manifest validation and client evidence. The separately authorized deployment operator owns production routes, storage, publisher, and feed state. A release operator owns approvals, archive and final GO. Never let a CLIENT agent deploy or publish the feed.

## Release invariants (non-negotiable)

- Android production package ID is `it.simogatti.myteam`; never change it after first distribution. `com.example.myteam_video_app` is QA-only. QA APKs, including historic A/B, are not production candidates.
- Android production signing uses one owner-controlled, long-lived JKS/certificate; QA and production fingerprints must differ. No debug fallback, regenerated key, or per-run key. Keep the alias, passwords, JKS, and private key outside Git and logs. Record only the verified public SHA-256 certificate fingerprint in the evidence record.
- Windows keeps Inno Setup AppId `{9B7E3E5C-62E8-4DA4-8FB7-F58552309AA2}`, per-user install/data behavior, and graceful Restart Manager shutdown. By owner decision, Authenticode is not required for launch; an unsigned installer may produce Windows trust warnings, and no trusted publisher identity is claimed. The Ed25519 manifest signature and SHA-256 artifact verification remain mandatory and fail closed. The current candidate workflow and validator still require Authenticode, so do not dispatch them until INFRA reconciles both with this policy and the changes are reviewed.
- Production updater trust root is the public Ed25519 key pinned in `lib/core/services/updater/release_key_pin.dart`. The signing key must derive exactly that public key. Never run the key-generation command for production, change the pin silently, put private material in code/argv, or bypass detached-signature validation. Rotation requires a separately designed and shipped trust-transition protocol.
- The detached signature covers the exact UTF-8 bytes of `version.json`; do not reformat or rewrite the file after signing. The manifest schema must match the current separately maintained deployment validator contract, including root keys `channel`, `version_name`, `version_code`, `release_date`, `changelog`, `mandatory`, `min_supported_version_code`, `platforms`; `channel` is `production`; and platform keys are exactly `android` and `windows`. URLs are exactly `https://myteam.simogatti.it/updates/releases/<version_name>/<filename>` (no query, fragment, userinfo, or alternate port). The producer derives this URL from the version; it is not a dispatch input. Both artifact filenames, byte sizes and SHA-256 values must match the bytes. The Flutter model accepts but does not interpret the extra `channel` field; runtime selection remains the compile-time feed URL/key. This preserves the distinct QA schema (whose validator intentionally has no `channel` field); production channel enforcement is performed by the candidate and deployment validators.
- Build once. Promote the identical APK, EXE, manifest, signature, and provenance bytes that passed validation and A′→B′ tests. Never rebuild between certification and promotion.
- CI artifacts (currently configured for 90-day retention) are transfer/staging only, not durable archival. Durable archive and independently restorable backup are mandatory before GO.
- Release preparation is manual. Pushes and ordinary CI must never publish. Candidate build, archive, preproduction test, and production publication are separate gates. The workflow in this branch builds/signs and uploads a candidate only; it does not deploy or publish the feed.

## Fixed lifecycle and gates

Record each phase as `PASS`, `HOLD`, or `NOT RUN`, with evidence paths/URLs and SHA-256 values, in a release record named `docs/APP/releases/<version>-<versionCode>.md` (or the private release archive if the record contains operationally sensitive metadata). Never put secrets or private key material in that record. Keep a copy of the final record with the archive. If a gate fails, stop at that phase; do not skip ahead.

### 0 — Identity and security gates — HOLD until verified

The owner must confirm the adopted production Android application ID, stable signing identity and certificate fingerprint; separate QA identity; stable Windows installer identity and the accepted unsigned-Authenticode policy; and the production Ed25519 manifest trust pin. All private signing material must remain outside source control, build logs, workflow inputs, and distributable artifacts. This document intentionally omits key-generation, escrow, provider, and credential-setting instructions. If any required identity or authorized signing process is unavailable or unverified, stop with `HOLD`; do not generate substitute keys, change pins, or weaken verification.

### 1 — Source and version freeze

- Freeze a reviewed commit on the trusted protected release ref. Record the exact commit SHA, repository/ref, review evidence, and clean-tree status in restricted release evidence. Do not include unreviewed changes or secrets-bearing workflow changes.
- Pin Flutter `3.38.1` (`.fvmrc`), Ubuntu runner `ubuntu-24.04`, Java 17, Windows runner `windows-2022`, Android build-tools `35.0.0`, and Inno Setup compiler `6.7.1`; retain `pubspec.lock` and enforce it (`flutter pub get --enforce-lockfile`). Record runner image identifiers and resolved tool versions from the actual run.
- Choose numeric `X.Y.Z` and a positive Android `versionCode` strictly greater than the last production code; record both and prior code. The same `version_name`/code identifies the Windows installer. Check both Android production `applicationId` and Inno AppId before building. No version reuse after any candidate bytes have escaped the private build environment.
- Review the release workflow and signing guards at the exact frozen SHA. Confirm required secrets are available by **name/presence only**, never display values. Record environment/branch restriction outcome and approver policy. Do not dispatch if branch protection/environment gating is not effective.

### 2 — Build and sign once (candidate only)

The candidate workflow is manual-only and must be present on the repository default branch before dispatch. Before use, the owner must verify that the selected immutable ref is protected, the workflow enforces the exact expected source SHA, required environment approvals are supported and configured, and required signing configuration is available to the authorized workflow. Check current account-plan capabilities and permissions; if an enforcement gate is unavailable, production automation remains `HOLD`. Never bypass the gate or print credential-setting names or values.

Review every third-party workflow dependency at its pinned full commit SHA and confirm it matches the intended upstream source; consider transitive dependencies. The workflow must not expose private signing material to untrusted pull requests or accept credentials as inputs.

**Dispatch template — do not execute without separate owner authorization for candidate creation:**

```sh
gh workflow run release-candidate.yml \
  --repo '<owner>/<repository>' \
  --ref '<trusted-protected-release-ref>' \
  -f expected_commit_sha='<FULL_FROZEN_SHA>' \
  -f version_name='<X.Y.Z>' \
  -f version_code='<MONOTONIC_INTEGER>' \
  -f previous_production_version_code='<LAST_PRODUCTION_CODE_OR_0>' \
  -f changelog='<REVIEWED_USER_FACING_NOTES>'
```

A workflow run only prepares a candidate; it does not authorize archive publication or feed deployment. Keep sensitive run identifiers and access-controlled evidence outside public documentation.

### 3 — Candidate validation and provenance

Run the candidate verifier against the extracted `release-candidate/` directory (contains both platform artifacts, `version.json`, `version.json.sig`, `build-provenance.json`, `SHA256SUMS`):

```sh
flutter pub get --enforce-lockfile
dart run tool/release_candidate.dart validate '<PRIVATE_CANDIDATE_DIR>'
dart run tool/sign_manifest.dart verify \
  '<PRIVATE_CANDIDATE_DIR>/version.json' \
  '<pinned-production-public-key-hex>' \
  '<PRIVATE_CANDIDATE_DIR>/version.json.sig'
```

The verifier checks exact production channel and Android/Windows entries, manifest signature against the pinned key, file names/lengths/SHA-256, provenance fields/toolchain and exact `SHA256SUMS` coverage. Independently inspect Android manifest ID and certificate with `aapt`/`apksigner`. Authenticode verification is optional under the accepted unsigned policy: if a signature is present, verify it with `signtool`; if absent, record that no trusted publisher identity is claimed and expect possible Windows warnings. In either case, Ed25519 manifest verification and SHA-256 artifact checks remain mandatory. Inspect installer upgrade behavior and the graceful Windows close/relaunch path. A metadata claim in JSON is not a substitute for binary signature verification. Any mismatch = `HOLD`; never edit files after signing. Save a verified archive checksum sidecar and independently verify it after extraction.

### 4 — Durable archive and recovery drill

The successful Actions run is temporary. Before A′→B′ testing or GO:

1. Store exact verified bundle archive, archive `.sha256`, individual `SHA256SUMS`, signed manifest, signature, provenance, sanitized provenance metadata, and release evidence in a **draft repository release** with access controls verified before upload, tagged with the candidate version and commit. Use a unique candidate tag such as `candidate-v<X.Y.Z>-build<N>`; create the tag at the frozen commit, never at an implicit default-branch tip. Example (only after owner authorizes archive creation):

   ```sh
   gh release create "candidate-v$VERSION-build$CODE" \
     "$BUNDLE" "$BUNDLE.sha256" "$RELEASE_RECORD" \
     --repo '<owner>/<repository>' --target "$FROZEN_SHA" --draft \
     --title "MyTeam $VERSION build $CODE candidate" \
     --notes-file "$RELEASE_NOTES"
   ```

   Do not make the repository or release public. A draft/private archive is not the production feed and does not authorize distribution. Read back the release metadata and asset names, download each asset to a fresh directory, and verify the archive checksum before using it.
2. Copy the same bytes to a second owner-controlled encrypted backup location with independent failure domain. No replacement/overwrite; use a new versioned path. Record storage reference and checksums, not access tokens. Example after approved destination paths exist:

   ```sh
   install -d -m 700 "$BACKUP_A/$TAG" "$BACKUP_B/$TAG"
   cp -n "$BUNDLE" "$BUNDLE.sha256" "$RELEASE_RECORD" "$BACKUP_A/$TAG/"
   cp -n "$BUNDLE" "$BUNDLE.sha256" "$RELEASE_RECORD" "$BACKUP_B/$TAG/"
   (cd "$BACKUP_A/$TAG" && shasum -a 256 -c "$(basename "$BUNDLE.sha256")")
   (cd "$BACKUP_B/$TAG" && shasum -a 256 -c "$(basename "$BUNDLE.sha256")")
   ```
3. From the secondary copy, restore into a clean isolated directory and rerun `verify-archive`, `validate`, and checksum checks; record evidence. Failure or unavailable independent backup = `HOLD`.
4. After test/promotion, preserve archive immutably; never replace an asset under a reused version/tag. Superseding a candidate uses a new monotonically increasing version code and a new archive.

Actions artifacts configured at 90 days are not this archive. GitHub Releases can be stored in a private repository; public visibility changes require a separate explicit owner decision. Archive uploads and backups are not to be done in this preparation task.

### 5 — Preproduction A′→B′ test — currently a hard blocker

Test on disposable Android emulator and Windows VM with test data, no user devices. Install **A′** normally; record app ID/AppId, version, certificate fingerprint, and pre-test local-data sentinel. Publish only to an isolated preproduction feed. Trigger the update in the app; do not use `adb install` or rerun the installer to install B′. Verify downloader signature/hash/size, install handoff, no manual close, upgrade without data loss, installed version B′ and signing identity unchanged; retain screenshots/logs with secrets and personal data removed. Also prove one unavailable-feed notification is non-blocking and self-dismisses in 5 seconds; malformed JSON, wrong channel, bad signature, wrong hash/size, rollback version, and unexpected redirects fail closed. Repeat Windows A′→B′ and verify Restart Manager/graceful close without force-kill.

**Current blocker:** no isolated production-identity staging feed has been validated. QA identity, signer, manifest key, and feed are not substitutes. A staging-specific client build that is not byte-identical to the promotable production build also does not satisfy build-once promotion. Before the first production release, the client maintainer and authorized deployment operator must document and test an isolated staging method that exercises the actual production identities and updater handoff without writing to the live production manifest. Until then this gate is `HOLD`; do not improvise a live-feed test.

### 6 — Explicit GO and publication plan

A release operator (owner) reviews all evidence and records a separate explicit GO for the exact candidate SHA, version/code, manifest hash, archive hash, and intended publication window. No agent infers GO from “proceed,” a passing workflow, a draft archive, prior QA, or this contract. If any prior phase is not `PASS`, GO is invalid.

Before any authorized publication, the deployment operator independently verifies readiness, the current supported publishing and rollback procedure, and backup/restore status. Client-side documentation does not provide deployment access details or establish live service readiness.

### 7 — Publish exact tested bytes (authorized deployment operator only)

This client repository does not publish feeds or deployment state. Only the separately authorized deployment operator may publish, using the current reviewed deployment procedure and its independent validation. Stage immutable, versioned Android/Windows artifacts and the detached manifest signature first; switch the production manifest pointer last using the documented atomic operation. Never overwrite prior versioned artifacts, use ad hoc file copies, or publish from a build job. If publisher validation or backup/restore readiness is uncertain, stop at `HOLD`. Record hashes and sanitized gate outcomes in restricted release evidence; do not include private endpoints, cluster details, access paths, or credentials in this repository.

### 8 — External smoke and closeout

From an independent client outside the deployment environment, GET the public production `version.json`, `.sig`, Android APK and Windows EXE over HTTPS. Require expected status, exact digest/length, no unexpected redirects, cache behavior required by the current deployment contract, correct manifest signature/channel/version, and successful Android+Windows in-app update checks where safe. Use a disposable test installation for install smoke; no user distribution until checks pass. Record status headers and UTC timestamp; do not record credentials. If any check fails, stop rollout and follow approved rollback.

### 9 — Rollback and key incident

- Rollback means atomically point the active manifest to the **previous still-valid, still-signed release** only after confirming its version policy is accepted by clients and its bytes remain available. Never edit APK/EXE bytes or fabricate an older signature. If clients reject downgrade, publish a new higher version code containing the rollback fix; do not lower the monotonic code.
- Preserve the failed candidate and evidence; stop new deployments and new candidate dispatches until root cause is known. Restore the prior valid manifest pointer using the documented safe rollback procedure and verify externally.
- Suspected Android keystore, Authenticode PFX, or Ed25519 private-key compromise: immediately stop release/feed writes, restrict access/revoke CI secret access, preserve audit evidence, contact the owner, and follow a separately approved client/server key-rotation plan. Android package signer cannot be silently replaced after distribution; Ed25519 rotation requires clients that trust the successor before signing with it. Never rotate/regenerate keys as a rollback shortcut.

## Current gate ledger (as observed 2026-11-11)

| Gate | Status | Evidence / blocker |
|---|---|---|
| Production Android ID and Windows Inno AppId policy | PASS (decision) | `RELEASE-BASELINE.md`, Gradle and Inno script; first prod distribution still not made |
| Android production JKS, 25-year cert, fingerprint, two backups + restore drill | HOLD | Baseline says not provisioned/verified; no key generated here |
| Windows Authenticode | NOT REQUIRED (owner decision) | Unsigned installer accepted; Windows warnings possible; no trusted publisher identity claimed. Current workflow and validator require a signer and must be reconciled/reviewed before use. |
| Existing Ed25519 private key matching client pin and recoverable escrow | HOLD | Baseline says not recovered/verified; pin exists in source |
| Native third-party binary provenance/license audit | DEFERRED — known debt (NOT VERIFIED) | Owner decision: complete after launch; this is not compliance clearance. |
| Candidate workflow default-branch availability | NOT VERIFIED | Check the public repository default branch and workflow presence before any authorized candidate dispatch. |
| Protected release branch / production Environment reviewers / plan support | NOT VERIFIED | Confirm applicable repository protections and environment approvals before any authorized candidate dispatch. |
| Immutable GitHub Action dependency pins | HOLD | workflow currently uses major-version tags (`@v4`, `@v3`, `@v2`); audited full-SHA pinning remains required |
| Production-signer isolated staging feed and true A′→B′ test | HOLD | No approved end-to-end staging evidence is recorded here; use the separately reviewed deployment procedure. |
| Candidate workflow/build/sign/archive | NOT RUN | only source/static inspection this task; workflow is manual, uploads 90-day artifacts |
| Durable GitHub Release + second backup + restore drill | NOT RUN | no archive created or uploaded |
| Deployment readiness, publisher validation, and external smoke | NOT RUN | no server access or deployment in this task |
| Owner's exact-version production GO | NOT GIVEN | required separately after all gates pass |

## Release evidence record

Keep only sanitized release evidence in this repository: version, source/artifact hashes, toolchain versions, signature-validation result, A′→B′ test status, and gate outcomes. Store access-controlled operational identifiers and private deployment/backup details only in the owner's restricted records, never in tracked documentation or public release notes. Mark anything not actually observed as `NOT RUN` or `NOT VERIFIED`; do not include credentials, private endpoints, personal data, or secret-setting names.
