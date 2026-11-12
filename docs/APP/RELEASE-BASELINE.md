# First production release baseline (2026-11-10)

> **Procedure:** [`PRODUCTION-RELEASE.md`](PRODUCTION-RELEASE.md) is the canonical execution contract for the first and every later production release. This file records adopted identity/security decisions only.

**Status: policy recorded; production release is HOLD.** This project has no pre-existing production installs, so the first distributed release establishes the permanent identity. Nothing in this document authorizes a feed write, public release, deployment, or distribution.

## Adopted identities and update safety

- Android first-party production `applicationId`: **`it.simogatti.myteam`**. `namespace` and Kotlin source package remain `com.example.myteam_video_app`; the namespace is not the installed package identity. QA builds explicitly select the legacy test-only `com.example.myteam_video_app` ID to keep existing QA A→B installs compatible. Historic QA A/B packages retain that legacy ID and QA signer and are not production candidates. No production user migration is needed. From the first production install onward, do not change the production ID or signer.
- Android production keystore/certificate: Infra reports the existing production JKS was generated without regeneration and its public certificate fingerprint is known: SHA-256 `2d3f30b82fef2d77a5f0f4077bb2a69b1be18d49426717925ffa579d2a1bed5e`. Private custody is reported complete; independent passphrase-recovery verification remains **PENDING**. Do not read or reproduce the keystore, passwords, or private materials. Android signing is an explicit build channel: `MYTEAM_ANDROID_SIGNING_CHANNEL=qa` selects only `MYTEAM_ANDROID_QA_*`; `production` selects only `MYTEAM_ANDROID_PROD_*`. Release tasks fail closed when channel, external keystore, credentials, or production SHA-256 certificate allowlist are missing/invalid. Debug builds do not use these release secrets. Keep this long-lived production JKS; never generate a replacement per release.
- Windows Authenticode: **intentionally omitted by owner choice**. The release workflow builds an unsigned installer and requires an explicit dispatch acknowledgement; SmartScreen/unknown-publisher warnings may occur. Provenance records `unsigned_owner_accepted` and does not claim Authenticode signing or publisher identity. The detached Ed25519 signature authenticates the manifest, not the EXE's Windows publisher. Windows keeps the existing Inno `AppId` `{9B7E3E5C-62E8-4DA4-8FB7-F58552309AA2}`, per-user `%LOCALAPPDATA%\Programs\MyTeam` install, and graceful/no-force-close restart policy.
- Production updater manifests are verified with the production-only Ed25519 public key pinned in the client; QA builds use a distinct QA pin and fixed QA paths. The approved production public key is `b7cb644d4d633d2def2e557cdd13382cc6b431292425d4b9f3cab0ba12c139b9`; it replaces the obsolete pin `5bf7930615b4240b316e0ffcdc9f014a23e773c749dbb79ad9a4b0cce016b234`, which had no matching definitive production private key. Infra reports that custody and backup of the corresponding new private signer were verified in its private runbook; no path or private material is recorded here. Independent passphrase recovery remains **PENDING**. Keep production signing on HOLD until recovery and CI controls pass. Sign the exact UTF-8 bytes stored as `version.json`; publish the detached Ed25519 signature as the matching `.sig`; verify SHA-256 and size for every package. A QA signature/key must never be accepted by a production client.
- `pubspec.yaml` is currently `0.2.0+2`; future version names/build codes must increase monotonically. Android `versionCode` is bounded by `2147483647`. Keep the same Android certificate and application ID for every production A→B upgrade.

## Signing identity controls — owner verification only

Infra reports the production Android JKS was generated and its public certificate fingerprint is known, and reports custody of the new Ed25519 private signer and its backup verified in a private runbook. This client-side work does not generate, rekey, move, install, retrieve, or inspect signing keys, and does not read or set secret values. Independent passphrase-recovery verification is still PENDING, and the required GitHub `production-release` secret names/presence have not been verified. Keep signed build dispatch on HOLD until both gates and the live CI controls are verified; do not create replacement keys as a workaround.

After independent passphrase-recovery verification and verification of the `production-release` environment controls, the owner may configure the CI secret names only in that GitHub Environment: `ANDROID_PROD_KEYSTORE_BASE64`, `ANDROID_PROD_STORE_PASSWORD`, `ANDROID_PROD_KEY_ALIAS`, `ANDROID_PROD_KEY_PASSWORD`, `ANDROID_PROD_CERT_SHA256`, `ANDROID_QA_CERT_SHA256`, and `MYTEAM_UPDATER_PROD_PRIVATE_KEY`. The values must never be placed in Git, workflow inputs, command arguments, logs, chat, or candidate artifacts. `MYTEAM_ANDROID_PROD_KEYSTORE_PATH` is a runtime path, not a secret. The workflow verifies the Android certificate allowlist and signs the exact manifest against the unchanged checked-in Ed25519 public-key pin. This documents GitHub Environment as the chosen CI boundary; it makes no claim about Infisical, ESO, or any infrastructure-side secret system.

Windows Authenticode remains intentionally omitted by owner choice; no Authenticode signing secret is required. Native third-party licensing/compliance review is deferred and unassessed, not attested.

## Build, certification, archive, and promotion policy

### Repeatable candidate workflow (owner/operator run only after all gates)

The single production candidate builder is `.github/workflows/release-candidate.yml`; use it for every release instead of ad hoc local builds. `main` is the only persistent protected source branch and the only permitted candidate ref; freeze its reviewed full commit SHA and dispatch against `main` with that exact SHA. The same manual process applies to first and later releases; it builds one version per run, signs the manifest in the protected `production-release` Environment, validates SHA-256/size/identity/signature, and uploads candidate artifacts. Public APK/EXE/Actions artifact visibility is accepted. Never place Android keystores/passwords or the Ed25519 private key in Git, command arguments, logs, or candidate files.

**Tentative first-release A′→B′ setup only:** if the owner confirms no production version has been promoted, use the baseline `0.2.0+2` and run two candidate builds from the same frozen source SHA and production identities:

| Run | `version_name` | `version_code` | `previous_production_version_code` |
|---|---:|---:|---:|
| A′ | `0.2.1` | `3` | `0` |
| B′ | `0.2.2` | `4` | `0` |

Set `acknowledge_unsigned_windows=true` in both runs. The `0` prior code remains the last **promoted** code during this pre-release test; it is not A′'s code. Validate both returned archives, install A′ on disposable Android/Windows devices, and use the controlled staging method to update in-app to the exact B′ artifact. The owner performs these emulator/VM tests; do not install B′ directly or change the live feed.

**Every subsequent update:** A is the last promoted production build; dispatch once to build candidate B with the same permanent Android identity/signer and pinned Ed25519 trust, setting `previous_production_version_code` to the last promoted code and choosing a strictly higher version code. Test the installed A→B update against isolated staging, preserve the exact tested B bytes, and promote only those bytes after the separate exact-version owner GO. Do not rebuild after certification. If isolation cannot test the exact candidate safely, keep release on HOLD.

For valid GitHub CLI dispatch syntax, workflow gates, artifact validation, and the full manual A→B checklist, follow [the canonical production release contract](PRODUCTION-RELEASE.md). The workflow input `expected_commit_sha` is supplied with `-f expected_commit_sha=<FULL_MAIN_SHA>` (not a custom `--expected-commit-sha` CLI flag). Do not create/rekey or move/install signing keys as part of routine release preparation. Windows Authenticode remains intentionally omitted; disclose SmartScreen/unknown-publisher risk. Native third-party license/compliance review remains deferred and unassessed, not attested.

## Current gates and safe workflows

- `.github/workflows/qa-updater-build.yml` remains a manual **QA-only** A/B artifact builder; it does not publish a feed. QA secrets remain QA-only.
- `.github/workflows/build.yml` is not the release workflow. The manual `.github/workflows/release-candidate.yml` is a candidate builder only; it does not publish or deploy. Windows Authenticode is intentionally not used. Native license/compliance review is deferred and not attested. No artifact-attestation claim is made.
- The GitHub API reports an active `Protect main` ruleset scoped to exactly `refs/heads/main`, with deletion, non-fast-forward, and linear-history rules and no bypass actors. The production `production-release` Environment branch restriction/reviewer policy and required secret-name presence remain **NOT VERIFIED**. Recheck live settings before any production CI run; do not infer environment safeguards from source. Prefer owner-approved, environment-scoped secrets; never expose production keys to workflows that do not require them. If the required controls cannot be enforced, keep CI signing and promotion blocked and use a controlled owner-run process.
- The evidence recorded here is source review and deterministic checks only. No production key was generated or read, no production release artifact or installer was produced, no candidate workflow was dispatched, and no production feed or server was changed.


## Windows installer shutdown and data preservation

The stable Inno Setup AppId and per-user `{localappdata}\Programs\MyTeam` install directory are retained. For in-app updates, Setup uses Windows Restart Manager (`CloseApplications=yes`) to request a graceful shutdown and release loaded DLLs before replacing files; it does not force-terminate the process. `RestartApplications=no` and the `/NORESTARTAPPLICATIONS` launcher flag prevent the prior build from racing the completed installation. The updater's active-task guard must permit handoff first. User data/settings must remain outside the application install tree; the installer must not add deletion rules for those locations.

**QA evidence/history:** the prior Windows QA A→B installer failed to replace `connectivity_plus_plugin.dll` while A was open, then succeeded after the user closed A and retried. The above behavior is the intended fix, but it is not considered verified until a fresh QA A build and a real Windows A→B in-app update pass without manual close/retry and with data retained. No production release is authorized by this note.

## Operational runbook

The canonical candidate and archive procedure is [PRODUCTION-RELEASE.md](PRODUCTION-RELEASE.md); older candidate notes are historical/superseded. Remaining HOLD gates include independent passphrase recovery, verification of required `production-release` secret-name presence and main-only Environment/reviewer controls, production artifact route, durable archive/independent backup, and owner-run staging A→B tests. Windows Authenticode is intentionally omitted by owner choice with SmartScreen warning risk; native license/compliance review remains deferred and unassessed. No candidate build authorizes publication.
