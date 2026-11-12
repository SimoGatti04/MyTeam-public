# MyTeam production release contract

**Authority:** canonical procedure for every production client release, first-user and later. This document supersedes release execution instructions in `RELEASE-CANDIDATE-RUNBOOK.md`; `RELEASE-BASELINE.md` remains the record of adopted identity/security decisions. Follow current source and the matching Infra production publisher contract before executing infrastructure steps.

**Current state (2026-11-12): HOLD — preparation only.** No production build, archive, preproduction A′→B′ verification, feed publication, deployment, or user distribution is authorized or evidenced by this document. An explicit operator GO is required separately for each production publication. A successful build or candidate archive is never a GO.

## Agent entry: read these first

1. Repository rules: [`/AGENTS.md`](../../AGENTS.md).
2. This contract (the one source of truth for releases).
3. [`RELEASE-BASELINE.md`](RELEASE-BASELINE.md) for adopted IDs, signing-key pin, and known identity gates.
4. [`RELEASE-CANDIDATE-RUNBOOK.md`](RELEASE-CANDIDATE-RUNBOOK.md) only as historical workflow-specific notes; it is superseded for procedure.
5. Client implementation: `android/app/build.gradle*`, `windows/installer/MyTeam-Setup.iss`, `lib/core/services/updater/updater_channel_config.dart`, `lib/core/services/updater/release_key_pin.dart`, `tool/release_candidate.dart`, `tool/sign_manifest.dart`, `lib/core/services/updater/manifest_signature_verifier.dart`, `.github/workflows/release-candidate.yml`.
6. Infra operator handoff: INFRA independently identifies the current reviewed infrastructure source and reads its production-updater operator guide, manifest validator, publisher, and documented command interface. CLIENT documentation does not embed infrastructure repository identifiers. Before any infrastructure operation, INFRA must verify that the reviewed source is current and separately confirm live routes, storage, workload readiness, and publication state; source manifests are not live-state evidence. If the current publisher contract differs from the client contract below, stop and reconcile before proceeding.

**Role split:** CLIENT owns identities/build/signing/manifest validation and client evidence. INFRA owns production route, PVC, publisher, and feed state. A release operator owns approvals, key custody, archive and final GO. Never let a CLIENT agent deploy or publish the feed.

## Release invariants (non-negotiable)

- Android production package ID is `it.simogatti.myteam`; never change it after first distribution. `com.example.myteam_video_app` is QA-only. QA APKs, including historic A/B, are not production candidates.
- Android production signing uses one owner-controlled, long-lived JKS/certificate; QA and production fingerprints must differ. No debug fallback, regenerated key, or per-run key. Keep the alias, passwords, JKS, and private key outside Git and logs. Record only the verified public SHA-256 certificate fingerprint in the evidence record.
- Windows keeps Inno Setup AppId `{9B7E3E5C-62E8-4DA4-8FB7-F58552309AA2}`, per-user install/data behavior, and graceful Restart Manager shutdown. **Owner decision:** the production installer is intentionally distributed without Authenticode. Windows may show SmartScreen or unknown-publisher warnings; tell testers/users before download and do not claim a verified publisher identity. The detached Ed25519 signature authenticates the manifest, and SHA-256 authenticates the downloaded bytes against that manifest; neither is Authenticode. Reintroducing Authenticode requires a separate owner decision and workflow/provenance change.
- Production updater trust root is the public Ed25519 key pinned in `lib/core/services/updater/release_key_pin.dart`. The signing key must derive exactly that public key. Never run the key-generation command for production, change the pin silently, put private material in code/argv, or bypass detached-signature validation. Rotation requires a separately designed and shipped trust-transition protocol.
- The detached signature covers the exact UTF-8 bytes of `version.json`; do not reformat or rewrite the file after signing. The exact Infra validator contract is root keys `channel`, `version_name`, `version_code`, `release_date`, `changelog`, `mandatory`, `min_supported_version_code`, `platforms`; `channel` is `production`; and platform keys are exactly `android` and `windows`. URLs are exactly `https://myteam.simogatti.it/updates/releases/<version_name>/<filename>` (no query, fragment, userinfo, or alternate port). The producer derives this URL from the version; it is not a dispatch input. Both artifact filenames, byte sizes and SHA-256 values must match the bytes. The Flutter model accepts but does not interpret the extra `channel` field; runtime selection remains the compile-time feed URL/key. This preserves the distinct QA schema (whose validator intentionally has no `channel` field); production channel enforcement is performed by the candidate and Infra validators.
- Build once. Promote the identical APK, EXE, manifest, signature, and provenance bytes that passed validation and A′→B′ tests. Never rebuild between certification and promotion.

- **Interface validation gate:** before any future dispatch, verify that the candidate builder’s CLI and provenance schema match the service-side validator. If the producer and validator disagree, keep the release on HOLD and reconcile their interfaces. Source-level checks do not establish signing or live publication.
- CI artifacts (currently configured for 90-day retention) are transfer/staging only, not durable archival. Durable archive and independently restorable backup are mandatory before GO.
- Release preparation is manual. Pushes and ordinary CI must never publish. Candidate build, archive, preproduction test, and production publication are separate gates. The workflow in this branch builds/signs and uploads a candidate only; it does not deploy or publish the feed.

## Fixed lifecycle and gates

Record each phase as `PASS`, `HOLD`, or `NOT RUN`, with evidence paths/URLs and SHA-256 values, in a release record named `docs/APP/releases/<version>-<versionCode>.md` (or the private release archive if the record contains operationally sensitive metadata). Never put secrets or private key material in that record. Keep a copy of the final record with the archive. If a gate fails, stop at that phase; do not skip ahead.

### 0 — Identity and custody bootstrap — HOLD until verified

**Android production keystore:** generate once only after the owner approves a secure offline workstation and custody plan. Do not run these commands in CI or this task. Interactive `keytool` prompts must collect passwords; do not pass passwords with command-line flags, shell variables in transcripts, or chat. Example owner procedure (replace paths/identity with approved values):

```sh
umask 077
mkdir -p "$SECURE_DIR/myteam-production"
chmod 700 "$SECURE_DIR/myteam-production"
keytool -genkeypair -v -keystore "$SECURE_DIR/myteam-production/myteam-prod.jks" \
  -storetype JKS -alias myteam-prod -keyalg RSA -keysize 4096 -validity 10000 \
  -dname 'CN=MyTeam Production, OU=Release, O=MyTeam'
chmod 600 "$SECURE_DIR/myteam-production/myteam-prod.jks"
keytool -exportcert -keystore "$SECURE_DIR/myteam-production/myteam-prod.jks" \
  -alias myteam-prod -file "$SECURE_DIR/myteam-production/myteam-prod-cert.der"
shasum -a 256 "$SECURE_DIR/myteam-production/myteam-prod-cert.der"
keytool -list -v -keystore "$SECURE_DIR/myteam-production/myteam-prod.jks" -alias myteam-prod
```

This is a one-time bootstrap recipe, not a claim that a key exists. Independently review certificate subject, expiry (at least 25 years from issue), and fingerprint; compare the real fingerprint to a production-signed APK using `apksigner verify --print-certs`. Encrypt and escrow two independent backups under owner-controlled access, store only their locations/identifiers (not contents) in the private release record, and complete a restore drill into an isolated temporary directory before adding CI secrets. Delete the restored temp copy securely. Missing, mismatched, expired, or unrestorable key = `HOLD`; never regenerate as a workaround.

**Windows Authenticode:** intentionally not used by owner choice for this release path. The Windows workflow requires an explicit unsigned-distribution acknowledgement, verifies that the produced EXE reports `NotSigned`, and records `windows_authenticode_status: unsigned_owner_accepted`; it does not collect a PFX, fingerprint, or signing password. SmartScreen/unknown-publisher warning risk remains. This is a documented risk acceptance, not a claim that the installer is signed or trusted by Windows.

**Native licensing/compliance review:** deferred as known debt by owner priority. It has not been assessed; candidate provenance records `native_license_compliance_status: deferred_not_assessed`. Do not describe the product or release as license-compliant or compliance-certified. This deferral does not remove any legal obligations.

**Feed Ed25519 signer:** recover the existing owner-controlled private key from encrypted escrow and verify the derived public key equals the checked-in pin. `tool/sign_manifest.dart` has a `generate-keys` command for test/bootstrap scenarios; it is explicitly **not** a production recovery or rotation method. Back up the matching key independently, encrypt it, perform a restore/sign/verify drill in an isolated directory, then remove plaintext test copies. If the matching key is unavailable, release is `HOLD` until a reviewed client trust-rotation protocol is implemented and distributed.

### 1 — Source and version freeze

- Freeze a reviewed commit on the protected `release/rc-myteam-first-user` branch. Record full 40-character commit SHA, repository, branch, review/approval evidence, and clean-tree status. Do not include unreviewed PR code or secrets-bearing workflow changes.
- Pin Flutter `3.38.1` (`.fvmrc`), Ubuntu runner `ubuntu-24.04`, Java 17, Windows runner `windows-2022`, Android build-tools `35.0.0`, and Inno Setup compiler `6.7.1`; retain `pubspec.lock` and enforce it (`flutter pub get --enforce-lockfile`). Record runner image identifiers and resolved tool versions from the actual run.
- Choose numeric `X.Y.Z` and a positive Android `versionCode` strictly greater than the last production code; record both and prior code. The same `version_name`/code identifies the Windows installer. Check both Android production `applicationId` and Inno AppId before building. No version reuse after any candidate bytes have escaped the private build environment.
- Review the release workflow and signing guards at the exact frozen SHA. Confirm required secrets are available by **name/presence only**, never display values. Record environment/branch restriction outcome and approver policy. Do not dispatch if branch protection/environment gating is not effective.

### 2 — Build and sign once (candidate only)

The only currently implemented build entrypoint is `.github/workflows/release-candidate.yml` with manual `workflow_dispatch`. A credential-free preflight fails unless the dispatch ref is exactly `release/rc-myteam-first-user`, GitHub reports it protected, the full expected SHA equals the dispatched SHA, numeric/version-code inputs are valid, and the operator explicitly acknowledges the unsigned-Windows warning risk. Android, Windows, and bundle jobs depend on that successful gate; they do not silently skip when protection is absent. The workflow pins its Actions dependencies to full upstream commit SHAs and installs Android build-tools `35.0.0` through the runner SDK manager. It pins Linux jobs to `ubuntu-24.04`, then checks the immutable commit, lockfile, Android ID/certificate fingerprint, intentional unsigned Windows state, Inno engine version, monotonic version, and production manifest signature. Provenance marks native license/compliance review `deferred_not_assessed`; no compliance scan or attestation is performed. Output remains Actions artifacts with 90-day retention; the workflow does not publish a feed or create a durable release archive, and source checks do not prove live repository/environment protection settings.

**Dispatch bootstrap gate:** GitHub requires a `workflow_dispatch` workflow file to exist on the repository default branch before the first manual trigger; the dispatched run can then target the protected release branch. Before first use, verify that the candidate workflow is present on the default branch and that the release ref is protected. Do not rely on stale local tracking refs.

Before use, an owner/operator must verify in GitHub repository Settings:

- The candidate workflow pins each third-party action to a full commit SHA with a version comment and uses runner-managed Android build-tools. This source-level pinning is not a full security audit of transitive dependencies; review each action’s maintenance, permissions, and behavior before any production dispatch.

- `release/rc-myteam-first-user` is actually protected and `github.ref_protected` evaluates true for the dispatch;
- Before dispatching any production candidate, an owner/release operator must verify the actual branch-protection, environment-approval, and secret-scope controls in the repository. Do not infer safeguards from source code, plan, or API metadata. If required approvals or environment-scoped secrets are unavailable, keep signing and promotion blocked; never fall back to repository-wide production secrets.
- Required secret names exist (presence only): `ANDROID_PROD_KEYSTORE_BASE64`, `ANDROID_PROD_STORE_PASSWORD`, `ANDROID_PROD_KEY_ALIAS`, `ANDROID_PROD_KEY_PASSWORD`, `ANDROID_PROD_CERT_SHA256`, `ANDROID_QA_CERT_SHA256`, and `MYTEAM_UPDATER_PROD_PRIVATE_KEY`. The workflow intentionally requires no Windows Authenticode secrets.

Before any future candidate dispatch, the owner/operator must verify the protected release ref, approval controls, and environment-scoped secret availability through authenticated repository controls. Do not infer safeguards from source code or incomplete API reads. If a required control cannot be confirmed, keep the release on HOLD; never request or expose token values in this document.

**Dispatch template — do not execute until Gates 0–1 pass and the owner explicitly authorizes candidate creation:**

```sh
gh workflow run release-candidate.yml \
  --repo SimoGatti04/MyTeam \
  --ref release/rc-myteam-first-user \
  -f expected_commit_sha='<FULL_FROZEN_SHA>' \
  -f version_name='<X.Y.Z>' \
  -f version_code='<MONOTONIC_INTEGER>' \
  -f previous_production_version_code='<LAST_PRODUCTION_CODE_OR_0>' \
  -f changelog='<REVIEWED_USER_FACING_NOTES>'
```

The workflow and release CLI intentionally have no artifact-URL override. The CLI is plain Dart and shares the Flutter-independent Ed25519 verifier; production CLI validation always uses the pinned production public key. The test-only Dart API-key seam is not a CLI option. Before a future release, verify this producer contract against the service-side validator; source-level tests are not evidence of a live publication.

No private value is a workflow input. Capture workflow run ID/URL, terminal conclusion, checked-out commit, toolchain, artifact IDs and hashes. A failed/unknown run is not a candidate; inspect it before any retry to prevent duplicates. Download only the named output from the exact successful run into a new private staging directory. Validate it before proceeding.

### 3 — Candidate validation and provenance

Run the candidate verifier against the extracted `release-candidate/` directory (contains both platform artifacts, `version.json`, `version.json.sig`, `build-provenance.json`, `SHA256SUMS`):

```sh
flutter pub get --enforce-lockfile
dart run tool/release_candidate.dart validate '<PRIVATE_CANDIDATE_DIR>'
dart run tool/sign_manifest.dart verify \
  '<PRIVATE_CANDIDATE_DIR>/version.json' \
  '<PINNED_PUBLIC_KEY_HEX>' \
  '<PRIVATE_CANDIDATE_DIR>/version.json.sig'
```

The verifier checks exact production channel and Android/Windows entries, manifest signature against the pinned key, file names/lengths/SHA-256, provenance fields/toolchain and exact `SHA256SUMS` coverage. Independently inspect Android package ID and certificate with `aapt`/`apksigner`; verify the Windows AppId/version and record that the installer is unsigned. Do not claim Authenticode publisher verification. Inspect installer upgrade behavior and graceful Windows close/relaunch. Provenance must say native license/compliance review is deferred and not assessed. Any mismatch = `HOLD`; never edit files after signing. Save a verified archive checksum sidecar and independently verify it after extraction.

### 4 — Durable archive and recovery drill

The successful Actions run is temporary. Before A′→B′ testing or GO:

1. Store the exact verified bundle archive, archive `.sha256`, individual `SHA256SUMS`, signed manifest, signature, provenance, workflow-run metadata, and release evidence in an owner-approved, access-controlled draft archive location, tagged with the candidate version and commit. Use a unique candidate tag such as `candidate-v<X.Y.Z>-build<N>`; create the tag at the frozen commit, never at an implicit default-branch tip. Example (only after owner authorizes archive creation):

   ```sh
   gh release create "candidate-v$VERSION-build$CODE" \
     "$BUNDLE" "$BUNDLE.sha256" "$RELEASE_RECORD" \
     --repo SimoGatti04/MyTeam --target "$FROZEN_SHA" --draft \
     --title "MyTeam $VERSION build $CODE candidate" \
     --notes-file "$RELEASE_NOTES"
   ```

   Do not make the repository or release public. A draft/private archive is not the production feed and does not authorize distribution. Read back the release metadata and asset names, download each asset to a fresh directory, and verify the archive checksum before using it.
2. Copy the same bytes to a second owner-controlled encrypted backup location with independent failure domain. No replacement/overwrite; use a new versioned path. Record storage reference and checksums, not access tokens. Example after approved destination paths exist:

   ```sh
   install -d -m 700 "$BACKUP_A/myteam/$TAG" "$BACKUP_B/myteam/$TAG"
   cp -n "$BUNDLE" "$BUNDLE.sha256" "$RELEASE_RECORD" "$BACKUP_A/myteam/$TAG/"
   cp -n "$BUNDLE" "$BUNDLE.sha256" "$RELEASE_RECORD" "$BACKUP_B/myteam/$TAG/"
   (cd "$BACKUP_A/myteam/$TAG" && shasum -a 256 -c "$(basename "$BUNDLE.sha256")")
   (cd "$BACKUP_B/myteam/$TAG" && shasum -a 256 -c "$(basename "$BUNDLE.sha256")")
   ```
3. From the secondary copy, restore into a clean isolated directory and rerun `verify-archive`, `validate`, and checksum checks; record evidence. Failure or unavailable independent backup = `HOLD`.
4. After test/promotion, preserve archive immutably; never replace an asset under a reused version/tag. Superseding a candidate uses a new monotonically increasing version code and a new archive.

Actions artifacts with configured retention are not a durable release archive. Keep the candidate archive access-controlled; changing its audience or publishing artifacts requires a separate explicit owner GO. Archive uploads and backups are outside this preparation task.

### 5 — Preproduction A′→B′ test — currently a hard blocker

Test on disposable Android emulator and Windows VM with test data, no user devices. Install **A′** normally; record app ID/AppId, version, Android certificate fingerprint, and pre-test local-data sentinel. Publish only to an isolated preproduction feed. Trigger the update in the app; do not use `adb install` or rerun the installer to install B′. Verify downloader signature/hash/size, install handoff, no manual close, upgrade without data loss, installed version B′ and Android signing identity unchanged; retain redacted evidence. Also prove unavailable-feed handling, malformed JSON, wrong channel, bad signature, wrong hash/size, rollback version, and unexpected redirects fail closed. Repeat Windows A′→B′, verify Restart Manager/graceful close without force-kill, and record the expected unsigned-installer warning risk; no Authenticode claim is made.

**Current blocker:** `UpdaterChannelConfig` fixes production clients to `https://myteam.simogatti.it/updates/version.json`; no isolated production-identity staging feed selector/route was found in this branch. QA's app ID, QA signer, QA manifest key, and QA feed are not substitutes. A staging-specific client build that is not byte-identical to the promotable production build also does not satisfy build-once promotion. Before the first production release, CLIENT and INFRA must document and test an isolated staging mechanism that exercises the actual production app identity, Android/Windows signers, pinned Ed25519 trust, and updater handoff without writing to the live production manifest. Until then this gate is `HOLD`; do not improvise a live-feed test.

### 6 — Explicit GO and publication plan

A release operator (owner) reviews all evidence and records a separate explicit GO for the exact candidate SHA, version/code, manifest hash, archive hash, and intended publication window. No agent infers GO from “proceed,” a passing workflow, a draft archive, prior QA, or this contract. If any prior phase is not `PASS`, GO is invalid.

Immediately before publishing, read the current Infra production publisher README/Makefile and match its actual supported command, lock/atomicity behavior and rollback procedure. Verify production Route/Ingress/HTTPS, PVC Bound and available space, expected service UID/permissions, backup/restore readiness, and publisher health. Record current manifest pointer and hashes. Deploy only the publisher/route configuration required for the approved release; no unrelated backend changes.

### 7 — Publish exact tested bytes (operator + Infra only)

- Stage exact archive artifact files and manifest/signature; recheck their hashes against the archived evidence. Transfer APK/EXE first to their immutable/versioned paths under the production artifact route.
- Verify both artifact URLs return the exact archived bytes, expected `Content-Length`, HTTPS, and cache policy before changing the active manifest.
- Publish `version.json.sig` and then atomically switch `version.json` **last** as the single update pointer. Use the Infra publisher's documented locking/atomic operation; never use an ad hoc `cp`, expose private keys, overwrite old versioned binaries, or publish a partially written pointer.
- Record exact Infra target/command, operator, UTC time, commit/run/tag, manifest/signature/artifact/archive hashes, route/PVC checks, and pre/post pointer. Do not let a GitHub build job publish automatically.

### 8 — External smoke and closeout

From outside the cluster, GET production `version.json`, `.sig`, Android APK and Windows EXE over HTTPS. Require expected status, exact digest/length, no unexpected redirects, cache behavior from the Infra contract, correct manifest signature/channel/version, and successful Android+Windows in-app update checks where safe. Use a disposable test installation for install smoke; no user distribution until checks pass. Record status headers and UTC timestamp; do not record credentials. If any check fails, stop rollout and follow approved rollback.

### 9 — Rollback and key incident

- Rollback means atomically point the active manifest to the **previous still-valid, still-signed release** only after confirming its version policy is accepted by clients and its bytes remain available. Never edit APK/EXE bytes or fabricate an older signature. If clients reject downgrade, publish a new higher version code containing the rollback fix; do not lower the monotonic code.
- Preserve the failed candidate and evidence; stop new deployments and new candidate dispatches until root cause is known. Restore the manifest pointer under Infra lock and verify externally.
- Suspected Android keystore or Ed25519 private-key compromise: immediately stop release/feed writes, restrict access/revoke CI secret access, preserve audit evidence, contact the owner, and follow a separately approved client/server key-rotation plan. Android package signer cannot be silently replaced after distribution; Ed25519 rotation requires clients that trust the successor before signing with it. Never rotate/regenerate keys as a rollback shortcut.

## Current gate ledger (as observed 2026-11-11)

| Gate | Status | Evidence / blocker |
|---|---|---|
| Production Android ID and Windows Inno AppId policy | PASS (decision) | `RELEASE-BASELINE.md`, Gradle and Inno script; first prod distribution still not made |
| Android production JKS, 25-year cert, fingerprint, two backups + restore drill | HOLD | Baseline says not provisioned/verified; no key generated here |
| Windows Authenticode | OWNER-ACCEPTED UNSIGNED | Explicit unsigned-distribution acknowledgement is required; SmartScreen/unknown-publisher warning risk; no Authenticode verification is claimed |
| Native licensing/compliance review | DEFERRED — NOT ASSESSED | Known debt; no compliance statement or attestation |
| Existing Ed25519 private key matching client pin and recoverable escrow | HOLD | Baseline says not recovered/verified; pin exists in source |
| Workflow dispatch bootstrap on default branch | HOLD | Verify the workflow is available on the default branch and the selected release ref is protected before any manual dispatch |
| Protected release branch / production Environment reviewers / private-plan support | NOT VERIFIED | local `gh auth status` reported invalid token; no Settings mutation or credential repair |
| Immutable GitHub Action dependency pins | HOLD | workflow currently uses major-version tags (`@v4`, `@v3`, `@v2`); audited full-SHA pinning remains required |
| Production-signer isolated staging feed and true A′→B′ test | HOLD | client uses fixed production manifest URL; no matching Infra contract available at the given local path |
| Candidate workflow/build/sign/archive | NOT RUN | only source/static inspection this task; workflow is manual, uploads 90-day artifacts |
| Durable GitHub Release + second backup + restore drill | NOT RUN | no archive created or uploaded |
| Production Route/PVC/UID/ingress/publisher + external smoke | NOT RUN | no server access or deployment in this task |
| Owner's exact-version production GO | NOT GIVEN | required separately after all gates pass |

## Release evidence record template

Create one private record per candidate with: version/name/code/prior code; repository/ref/full commit; workflow run ID and conclusion; Flutter/JDK/runner/Inno versions; Android package ID and verified signer SHA-256; Windows AppId/version and `unsigned_owner_accepted` status (no Authenticode fingerprint); `native_license_compliance_status: deferred_not_assessed`; pinned Ed25519 key identifier (public hex only); `version.json` and `.sig` hashes; APK/EXE sizes and SHA-256; `SHA256SUMS`; archive hash and both backup references; A′→B′ Android/Windows device/OS results and data-retention sentinel; security negative-test results; GO record; Infra target/UTC/pointer hashes; external smoke statuses/headers; rollback readiness and final state (`candidate`, `archived`, `staged`, `published`, `rolled_back`). Every item not actually observed must say `NOT RUN` or `NOT VERIFIED`; do not claim native license/compliance clearance.
