# First production release baseline (2026-11-10)

> **Procedure:** [`PRODUCTION-RELEASE.md`](PRODUCTION-RELEASE.md) is the canonical execution contract for the first and every later production release. This file records adopted identity/security decisions only.

**Status: policy recorded; production release is HOLD.** This project has no pre-existing production installs, so the first distributed release establishes the permanent identity. Nothing in this document authorizes a feed write, public release, deployment, or distribution.

## Adopted identities and update safety

- Android first-party production `applicationId`: **`it.simogatti.myteam`**. `namespace` and Kotlin source package remain `com.example.myteam_video_app`; the namespace is not the installed package identity. QA builds explicitly select the legacy test-only `com.example.myteam_video_app` ID to keep existing QA A→B installs compatible. Historic QA A/B packages retain that legacy ID and QA signer and are not production candidates. No production user migration is needed. From the first production install onward, do not change the production ID or signer.
- Android production keystore/certificate: **not provisioned or verified**. Public production certificate SHA-256 fingerprint: **NOT AVAILABLE—record the real digest after owner-authorized one-time key creation; never substitute a placeholder**. Android signing is an explicit build channel: `MYTEAM_ANDROID_SIGNING_CHANNEL=qa` selects only `MYTEAM_ANDROID_QA_*`; `production` selects only `MYTEAM_ANDROID_PROD_*`. Release tasks fail closed when channel, external keystore, credentials, or production SHA-256 certificate allowlist are missing/invalid. Debug builds do not use these release secrets. The production keystore must be the one long-lived owner-controlled JKS (certificate validity at least 10,000 days); never generate a replacement per release.
- Windows Authenticode: **intentionally omitted by owner choice**. The release workflow builds an unsigned installer and requires an explicit dispatch acknowledgement; SmartScreen/unknown-publisher warnings may occur. Provenance records `unsigned_owner_accepted` and does not claim Authenticode signing or publisher identity. The detached Ed25519 signature authenticates the manifest, not the EXE's Windows publisher. Windows keeps the existing Inno `AppId` `{9B7E3E5C-62E8-4DA4-8FB7-F58552309AA2}`, per-user `%LOCALAPPDATA%\Programs\MyTeam` install, and graceful/no-force-close restart policy.
- Production updater manifests are verified with the production-only Ed25519 key pinned in the client; QA builds use a distinct QA pin and fixed QA paths. The current source pin is `5bf7930615b4240b316e0ffcdc9f014a23e773c749dbb79ad9a4b0cce016b234`. Its matching private-key custody and recovery have **not** been verified in this task. Keep the pin unchanged until the owner proves the matching signing key is recoverable, or approves a one-time pre-release replacement and then rebuilds the client. Never rotate silently. Sign the exact UTF-8 bytes stored as `version.json`; publish the detached Ed25519 signature as the matching `.sig`; verify SHA-256 and size for every package. A QA signature/key must never be accepted by a production client.
- `pubspec.yaml` is currently `0.2.0+2`; future version names/build codes must increase monotonically. Android `versionCode` is bounded by `2147483647`. Keep the same Android certificate and application ID for every production A→B upgrade.

## Key custody bootstrap — operator only, not executed

Do this once on a trusted owner-controlled macOS/Linux machine, outside any Git checkout and CI runner. Use a newly provisioned encrypted volume or owner-only directory (mode `0700`), and do not put any password or private key in command arguments, shell history, chat, source, or logs.

1. **Android upload/release keystore:** after confirming there is no authoritative production keystore, generate exactly one JKS with `keytool -genkeypair -alias myteam-prod -keyalg RSA -keysize 3072 -validity 10000 -storetype JKS -keystore /SECURE/PATH/myteam-prod.jks`. Let `keytool` prompt interactively for store/key passwords and certificate identity. Do not run this command from this task or in CI. Export only the public certificate and record its SHA-256 fingerprint (`keytool -exportcert ... | shasum -a 256`). Confirm it matches the certificate read back from a signed APK (`apksigner verify --print-certs`).
2. Make two encrypted backups on separate owner-controlled media/providers. Record the key alias, creation date, certificate expiry, public SHA-256 fingerprint, backup locations by access-controlled reference, and two-person/owner recovery procedure—never the private bytes or passwords in this repository. Verify both encrypted copies by restoring to a temporary owner-only location and confirming the same alias and public fingerprint; delete the temporary restored copy securely after the drill. Do not replace the primary key after the drill.
3. Provision `MYTEAM_ANDROID_PROD_KEYSTORE_PATH`, `MYTEAM_ANDROID_PROD_STORE_PASSWORD`, `MYTEAM_ANDROID_PROD_KEY_ALIAS`, `MYTEAM_ANDROID_PROD_KEY_PASSWORD`, and public `MYTEAM_ANDROID_PROD_CERT_SHA256` plus `MYTEAM_ANDROID_QA_CERT_SHA256` through an approved protected production signing environment. The Gradle release guard requires both valid fingerprints, rejects equality, and verifies the loaded production alias certificate against the production allowlist. The key file path must resolve outside the checkout. Do not use the QA repository secrets for production.
4. **Ed25519 manifest signer:** after confirming the pinned public key has no recoverable matching private key, get explicit owner approval before the one-time key creation/re-pin. `dart run tool/generate_keys.dart /SECURE/PATH/myteam-prod-ed25519.private` is an existing macOS/Linux-only helper that writes an owner-only new file and prints the public hex (public output only). Run only with the secure volume mounted, then make and restore two encrypted backups and verify a test signature offline. Store only the public hex in `lib/core/services/updater/release_key_pin.dart`; keep the private key offline. QA and production public keys must differ. No key generation, rotation, secret upload, or fingerprint enrollment was performed for this baseline.
5. **Windows Authenticode owner decision:** intentionally deferred/not used for this release. Do not configure or request an Authenticode secret; disclose the SmartScreen/unknown-publisher warning risk. Any future decision to add signing requires separate approval and a workflow/provenance update.

6. **Known debt — native licenses/compliance:** review is deferred and has not been performed. Candidate provenance must say `deferred_not_assessed`; do not claim compliance or certification. This records process status, not legal clearance.

## Build, certification, archive, and promotion policy

### Deterministic candidate commands (operator run only after all gates)

These are instructions, **not commands executed in this task**. Set secret values only in the trusted local environment/approved protected runner; never put them in CLI arguments. Base values are `0.2.0+2`, so the first production A/B candidate may be `0.2.1+3` and `0.2.2+4` if no production version has been assigned in the meantime.

Android, on the pinned Flutter/JDK/Android toolchain:

```bash
mkdir -p release-candidate
flutter pub get --enforce-lockfile
export MYTEAM_ANDROID_SIGNING_CHANNEL=production
flutter build apk --release --build-name=0.2.1 --build-number=3
cp build/app/outputs/flutter-apk/app-release.apk release-candidate/MyTeam-A-0.2.1+3.apk
flutter build apk --release --build-name=0.2.2 --build-number=4
cp build/app/outputs/flutter-apk/app-release.apk release-candidate/MyTeam-B-0.2.2+4.apk
```

The approved signer variables must already be present in the process environment; the production commands intentionally omit all QA `--dart-define`s. Before accepting either APK, run `apksigner verify --print-certs` and verify the output certificate SHA-256 equals `MYTEAM_ANDROID_PROD_CERT_SHA256` and differs from the separately recorded `MYTEAM_ANDROID_QA_CERT_SHA256`; inspect `aapt dump badging` for `it.simogatti.myteam` and exact version name/code. Gradle also loads the configured keystore, verifies alias/private-key access, checks its certificate fingerprint, enforces at least 25 years remaining validity, and rejects QA/production channel mismatch.

Windows, only on a genuine Windows x64 release runner with Flutter 3.38.1 and Inno Setup 6.7.1. The owner-approved build is intentionally unsigned and the workflow records this warning-risk decision:

```powershell
flutter pub get --enforce-lockfile
flutter build windows --release --build-name 0.2.1 --build-number 3
& $iscc "/DMyAppVersion=`"0.2.1`"" "/DMyAppBuildNumber=3" "/FMyTeam-Setup-0.2.1-3" "/Orelease-candidate" 'windows/installer/MyTeam-Setup.iss'
```

Repeat the Flutter build and ISCC invocation for `0.2.2` / build `4`. Do not Authenticode-sign the installer in this release path. Verify the Inno AppId, version, architecture, and installer behavior; record `NotSigned` and disclose the SmartScreen/unknown-publisher warning risk. This is an explicit owner-approved unsigned distribution choice, not a certificate verification.

After certification, create the release checksum index and verify it before and after each copy:

```bash
cd release-candidate
shasum -a 256 MyTeam-A-0.2.1+3.apk MyTeam-B-0.2.2+4.apk MyTeam-Setup-0.2.1-3.exe MyTeam-Setup-0.2.2-4.exe > SHA256SUMS
shasum -a 256 -c SHA256SUMS
```

Keep the signing manifest operation on the owner-controlled offline signer: use the existing `tool/sign_manifest.dart sign <version.json>` only after verifying the manifest contents/version/artifact SHA-256 and key custody. It writes the detached `.sig` beside the exact manifest bytes and refuses a private key that does not derive the client’s pinned production public key. Do not run it with `--allow-custom-key` for production. Copy neither the private key nor passwords into the candidate directory.

1. Release candidates must be built from a reviewed, immutable commit/tag on a trusted protected ref with Flutter **3.38.1**, the lockfile enforced, JDK/Gradle/Android SDK/Windows runner versions recorded, and no secrets exposed to fork/untrusted PR code. A→B version codes must strictly increase; A and B must use the same Android signer certificate, app ID, production feed key, and installer AppId. Verify the APK package/version/certificate, Windows x64 installer version/AppId and expected unsigned state, manifest signature, endpoint/channel, and SHA-256 before device tests.
2. Gate production GO on full updater A→B tests using disposable Android and Windows environments: install A, preserve app-local data through the in-app B update, prove the startup unavailable notice is one transient ~5-second notice and disappears, prove 404/503/offline handling, reject missing/bad signatures, wrong channel/version and artifact hash mismatch, and ensure update does not force-close during active upload. Do not install B directly for the updater test. Rollback is a higher monotonic version signed by the same permanent keys; never downgrade or reuse a version code.
3. **Build once, promote exact bytes.** Current QA workflow builds QA-key/QA-feed packages; these are not eligible for production promotion. A production-key candidate currently targets the production manifest URL while QA builds target separate fixed QA URLs and keys. Therefore the current setup cannot certify an identical production-configured binary against the isolated QA feed. Before claiming build-once promotion, agree with INFRA on a non-production routing method that presents the candidate feed at the production client's fixed HTTPS URL to disposable test devices, and sign candidate manifests offline with the production Ed25519 key. Do not put that key on the QA server or in CI. If this isolated route cannot be delivered safely, treat QA build and production build as separate artifacts and explicitly waive build-once promotion before any release; do not silently rebuild after certification.
4. After exact bytes pass A→B, archive APK/EXE, signed manifest and `.sig`, public cert/fingerprint, `SHA256SUMS`, source commit, workflow/run ID, toolchain, package/AppId/version metadata, and test evidence under a versioned release record. Verify checksums after every copy and retain two independently controlled backups. Actions artifacts are temporary transport, not the archive (current QA artifacts expire after seven days). A GitHub Release is not assumed immutable: restrict release write access, enable immutable-release protections if the repository/account actually offers them, and keep a separate encrypted/immutable backup. Never rebuild to “restore” a missing artifact.
5. Publish the manifest and binaries only after a separate explicit owner GO and QA sign-off; preserve previous known-good files for rollback. Feed publication and production deployment are outside this client change.

## Current gates and safe workflows

- `.github/workflows/qa-updater-build.yml` remains a manual **QA-only** A/B artifact builder; it does not publish a feed. QA secrets remain QA-only.
- `.github/workflows/build.yml` is not the release workflow. The manual `.github/workflows/release-candidate.yml` is a candidate builder only; it does not publish or deploy. Windows Authenticode is intentionally not used. Native license/compliance review is deferred and not attested. No artifact-attestation claim is made.
- Before any future production CI run, verify that the release ref is protected and that approval and signing-secret controls are enforced using the current repository interface. Do not infer safeguards from plan or API metadata. Prefer owner-approved, environment-scoped secrets; never expose production keys to workflows that do not require them. If the required controls cannot be enforced, keep CI signing and promotion blocked and use a controlled owner-run process.
- The evidence recorded here is source review and deterministic checks only. No production key was generated or read, no production release artifact or installer was produced, no candidate workflow was dispatched, and no production feed or server was changed.


## Windows installer shutdown and data preservation

The stable Inno Setup AppId and per-user `{localappdata}\Programs\MyTeam` install directory are retained. For in-app updates, Setup uses Windows Restart Manager (`CloseApplications=yes`) to request a graceful shutdown and release loaded DLLs before replacing files; it does not force-terminate the process. `RestartApplications=no` and the `/NORESTARTAPPLICATIONS` launcher flag prevent the prior build from racing the completed installation. The updater's active-task guard must permit handoff first. User data/settings must remain outside the application install tree; the installer must not add deletion rules for those locations.

**QA evidence/history:** the prior Windows QA A→B installer failed to replace `connectivity_plus_plugin.dll` while A was open, then succeeded after the user closed A and retried. The above behavior is the intended fix, but it is not considered verified until a fresh QA A build and a real Windows A→B in-app update pass without manual close/retry and with data retained. No production release is authorized by this note.

## Operational runbook

The canonical candidate and archive procedure is [PRODUCTION-RELEASE.md](PRODUCTION-RELEASE.md); older candidate notes are historical/superseded. Remaining HOLD gates include the production Android JKS/fingerprint, recoverable private key matching the pinned Ed25519 key, effective protected environment/ref controls, production artifact route, durable archive/independent backup, and real staging A→B tests. Windows Authenticode is intentionally omitted by owner choice with SmartScreen warning risk; native license/compliance review remains deferred and unassessed. No candidate build authorizes publication.
