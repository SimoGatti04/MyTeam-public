# MyTeam production release contract

**Authority:** canonical procedure for every production client release, first and subsequent. This document supersedes release execution instructions in `RELEASE-CANDIDATE-RUNBOOK.md`; `RELEASE-BASELINE.md` remains the record of adopted identity/security decisions. Follow current source and the matching Infra production publisher contract before executing infrastructure steps.

**Current state (2026-11-12): HOLD — preparation only.** No production build, archive, preproduction A→B verification, feed publication, deployment, or user distribution is authorized or evidenced by this document. An explicit operator GO is required separately for each production publication. A successful build or candidate archive is never a GO.

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
- Build once. Promote the identical APK, EXE, manifest, signature, and provenance bytes that passed validation and A→B tests. Never rebuild between certification and promotion.

- **Interface validation gate:** before any future dispatch, verify that the candidate builder’s CLI and provenance schema match the service-side validator. If the producer and validator disagree, keep the release on HOLD and reconcile their interfaces. Source-level checks do not establish signing or live publication.
- Candidate APK/EXE and Actions artifacts may be publicly visible by owner decision; public visibility is not a release blocker. Actions artifacts have 90-day retention and are not durable archival. Preserve exact candidate bytes and checksums for testing and promotion; do not rebuild after certification.
- Release preparation is manual. Pushes and ordinary CI must never publish the production feed. Candidate build, archive, preproduction test, and production publication are separate gates. The workflow builds/signs and uploads candidate artifacts only; it does not deploy or publish the feed.

## Fixed lifecycle and gates

Record each phase as `PASS`, `HOLD`, or `NOT RUN`, with evidence paths/URLs and SHA-256 values, in a release record named `docs/APP/releases/<version>-<versionCode>.md` (or in an owner-selected record location if it contains operationally sensitive metadata). Never put secrets or private key material in that record. Keep a copy of the final record with the archive. If a gate fails, stop at that phase; do not skip ahead.

### 0 — Signing identity and CI boundary — HOLD until owner-verified

Infra reports that the existing Android production JKS was generated without regeneration, the public certificate fingerprint is known, and custody plus backup of the newly pinned Ed25519 private signer were verified in a private Infra runbook. The Ed25519 public key now pinned in the client is `b7cb644d4d633d2def2e557cdd13382cc6b431292425d4b9`; it replaces the obsolete pin that had no definitive matching production private key. The Android certificate fingerprint is `2d3f30b82fef2d77a5f0f4077bb2a69b1be18d49426717925ffa579d2a1bed5`. No private runbook path or secret material belongs in this repository. Independent passphrase-recovery verification remains PENDING, and GitHub `production-release` secret-name presence remains NOT VERIFIED. Do not generate, rekey, move, install, retrieve, or inspect signers as part of this pipeline setup. Do not read or set secret values. Keep signed builds on HOLD until those recovery and CI gates pass.

After independent passphrase recovery and the live GitHub `production-release` Environment branch/reviewer controls are verified, configure the required **secret names only** in that Environment. The active GitHub `Protect main` ruleset is scoped to `refs/heads/main`; environment policy and secret presence still require separate verification. The workflow requires the names listed in `RELEASE-BASELINE.md`; it intentionally has no Authenticode secret. The GitHub Environment is the chosen CI signing boundary. No claim is made about Infisical/ESO or other infrastructure-side secret systems. Keep production JKS/passwords and the Ed25519 private key protected; candidate APK/EXE and Actions artifact visibility may be public by owner choice.

**Windows Authenticode:** intentionally not used by owner choice. The workflow requires explicit unsigned-distribution acknowledgement, verifies `NotSigned`, and records `windows_authenticode_status: unsigned_owner_accepted`; disclose SmartScreen/unknown-publisher warning risk. This is not an Authenticode trust claim.

**Native licensing/compliance:** deferred as known debt and not assessed. Candidate provenance records `native_license_compliance_status: deferred_not_assessed`. This is not a technical pipeline gate or compliance attestation and does not remove legal obligations.

### 1 — Source and version freeze

- Freeze a reviewed commit on the sole protected `main` branch. Record its full 40-character commit SHA, repository, review/approval evidence, and clean-tree status. Do not include unreviewed PR code or secrets-bearing workflow changes.
- Pin Flutter `3.38.1` (`.fvmrc`), Ubuntu runner `ubuntu-24.04`, Java 17, Windows runner `windows-2022`, Android build-tools `35.0.0`, and Inno Setup compiler `6.7.1`; retain `pubspec.lock` and enforce it (`flutter pub get --enforce-lockfile`). Record runner image identifiers and resolved tool versions from the actual run.
- Choose numeric `X.Y.Z` and a positive Android `versionCode` strictly greater than the last production code; record both and prior code. The same `version_name`/code identifies the Windows installer. Check both Android production `applicationId` and Inno AppId before building. No version reuse after candidate bytes have been generated or distributed; public candidate artifacts are acceptable by owner decision.
- Review the release workflow and signing guards at the exact frozen SHA. Confirm required secrets are available by **name/presence only**, never display values. Record environment/branch restriction outcome and approver policy. Do not dispatch if branch protection/environment gating is not effective.

### 2 — Build and sign once (candidate only)

The only implemented build entrypoint is `.github/workflows/release-candidate.yml` with manual `workflow_dispatch`. A credential-free preflight fails unless the dispatch ref is exactly `refs/heads/main`, GitHub reports `main` protected, the full expected SHA equals the dispatched SHA, numeric/version-code inputs are valid, and the operator explicitly acknowledges the unsigned-Windows warning risk. Android, Windows, and bundle jobs depend on that successful gate; they do not silently skip when protection is absent. The workflow pins its Actions dependencies to full upstream commit SHAs and installs Android build-tools `35.0.0` through the runner SDK manager. It pins Linux jobs to `ubuntu-24.04`, then checks the immutable commit, lockfile, Android ID/certificate fingerprint, intentional unsigned Windows state, Inno engine version, monotonic version, and production manifest signature. Provenance marks native license/compliance review `deferred_not_assessed`; no compliance scan or attestation is performed. Output remains Actions artifacts with 90-day retention; the workflow does not publish a feed or create a durable release archive, and source checks do not prove live repository/environment protection settings.

**Dispatch bootstrap gate:** GitHub requires the `workflow_dispatch` workflow file on the repository default branch. `main` is the only source ref for production candidates, and the GitHub API currently reports an active `Protect main` ruleset for exactly `refs/heads/main` (deletion, non-fast-forward, and linear-history rules; no bypass actors). The `production-release` Environment main-only branch restriction/reviewer controls and required secret-name presence remain **NOT VERIFIED**. Verify those settings in repository Settings before any dispatch. Do not infer live controls from source code or stale local refs.

Before use, an owner/operator must verify in GitHub repository Settings:

- The candidate workflow pins each third-party action to a full commit SHA with a version comment and uses runner-managed Android build-tools. This source-level pinning is not a full security audit of transitive dependencies; review each action’s maintenance, permissions, and behavior before any production dispatch.

- A branch ruleset/protection applies only to the exact `main` branch; enable no-force-push and no-delete controls and a solo-owner-appropriate review policy. `github.ref_protected` must evaluate `true` for `main` before signing jobs can run;
- Before dispatching any production candidate, an owner/release operator must verify the actual branch-protection, environment-approval, and secret-scope controls in the repository. Do not infer safeguards from source code, plan, or API metadata. If required approvals or environment-scoped secrets are unavailable, keep signing and promotion blocked; never fall back to repository-wide production secrets.
- Required secret names exist (presence only): `ANDROID_PROD_KEYSTORE_BASE64`, `ANDROID_PROD_STORE_PASSWORD`, `ANDROID_PROD_KEY_ALIAS`, `ANDROID_PROD_KEY_PASSWORD`, `ANDROID_PROD_CERT_SHA256`, `ANDROID_QA_CERT_SHA256`, and `MYTEAM_UPDATER_PROD_PRIVATE_KEY`. The workflow intentionally requires no Windows Authenticode secrets.

Before any future candidate dispatch, the owner/operator must verify protected `main`, approval controls, and environment-scoped secret availability through authenticated repository controls. Do not infer safeguards from source code or incomplete API reads. If a required control cannot be confirmed, keep the release on HOLD; never request or expose token values in this document.

**Dispatch template — do not execute until Gates 0–1 pass and the owner explicitly authorizes candidate creation. The candidate ref is always `main`; freeze and verify its full SHA immediately before dispatch:**

```sh
gh workflow run release-candidate.yml \
  --repo SimoGatti04/MyTeam-public \
  --ref main \
  -f expected_commit_sha='<FULL_MAIN_SHA>' \
  -f version_name='<X.Y.Z>' \
  -f version_code='<MONOTONIC_INTEGER>' \
  -f previous_production_version_code='<LAST_PRODUCTION_CODE_OR_0>' \
  -f acknowledge_unsigned_windows=true \
  -f changelog='<REVIEWED_USER_FACING_NOTES>'
```

The workflow and release CLI intentionally have no artifact-URL override. The CLI is plain Dart and shares the Flutter-independent Ed25519 verifier; production CLI validation always uses the pinned production public key. The test-only Dart API-key seam is not a CLI option. Before a future release, verify this producer contract against the service-side validator; source-level tests are not evidence of a live publication.

No private value is a workflow input. Capture workflow run ID/URL, terminal conclusion, checked-out commit, toolchain, artifact IDs and hashes. A failed/unknown run is not a candidate; inspect it before any retry to prevent duplicates. Download only the named output from the exact successful run into a new isolated staging directory. Validate it before proceeding.

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

The successful Actions run is temporary. Before A→B testing or GO:

1. Preserve the exact verified bundle archive, archive `.sha256`, individual `SHA256SUMS`, signed manifest, signature, provenance, workflow-run metadata, and release evidence under a unique candidate label such as `candidate-v<X.Y.Z>-build<N>` bound to the frozen commit. Actions artifacts may be used for candidate transfer; their configured 90-day retention is temporary, so keep a durable owner-approved copy before GO. Public visibility is accepted by owner decision, but a candidate artifact is not the production feed and does not authorize feed publication. Restore the retained copy into a fresh directory and verify the archive checksum before using it.
2. Keep a second durable copy with an independent failure domain if required by the owner archive plan. Candidate artifacts need not be encrypted for secrecy; the signing keys remain separately protected. Verify checksums after each copy.


3. From the secondary copy, restore into a clean isolated directory and rerun `verify-archive`, `validate`, and checksum checks; record evidence. Failure or unavailable independent backup = `HOLD`.
4. After test/promotion, preserve archive immutably; never replace an asset under a reused version/tag. Superseding a candidate uses a new monotonically increasing version code and a new archive.

Actions artifacts are not a durable release archive. Retain exact candidate bytes and checksums in an owner-approved durable location; public visibility is acceptable by owner decision. Do not publish the production feed or distribute a release to users without the separate exact-version GO.

### 5 — Candidate preparation and owner-run A→B test — HOLD until staging is confirmed

**Tentative first-release proposal only:** the source baseline is `0.2.0+2`, and no production installs are recorded. If the owner confirms there has been no prior production release, use A′=`0.2.1+3` and B′=`0.2.2+4`; this is not a version assignment or GO. For every later update, A is the last promoted production version and B is the new candidate, with a code strictly greater than the last promoted code. Owner selects the exact version and changelog before dispatch.

The workflow builds exactly one version per run. For the tentative first release, dispatch it twice from the same approved frozen `main` SHA: A′=`0.2.1+3`, then B′=`0.2.2+4`; set `previous_production_version_code=0` in both runs only if no production version has been promoted. Use the same production Android JKS/certificate and the same Ed25519 private key matching the pinned public key. For later updates, use the last promoted production artifact as A and run the workflow once for new B, setting `previous_production_version_code` to the last promoted code. Keep run IDs distinct, validate the exact artifact/checksum from each successful run, and preserve the exact tested B APK/EXE/manifest/signature bytes; never rebuild B after testing. Public artifact visibility is accepted and is not a gate.

**Owner manual device checklist (agents do not run emulator/VM upgrades):** Use the tentative first-release A/B pair above for the first-install test; for later releases install the last promoted A and update to candidate B.

1. Have INFRA confirm a controlled, isolated staging route that serves the production client’s fixed HTTPS host/path to disposable devices, with valid TLS, while leaving the live production feed and publication pointer unchanged. The candidate manifest and signature must remain byte-for-byte unchanged. If this cannot be confirmed, stop; do not test against the live feed or substitute QA identity/feed/key.
2. On a disposable Android emulator, install only A′ normally; record app ID `it.simogatti.myteam`, A′ version/code, production signing certificate fingerprint, and a harmless app-data sentinel. Point the emulator’s test network to the controlled staging route. Trigger update inside A′ so it downloads and installs the exact B′ APK from its candidate bundle—do not install B′ with `adb install`. Confirm B′ version/code, same package and certificate, retained sentinel, verified signature/hash/size, and no unexpected redirect.
3. On a disposable Windows VM, install only A′ normally; record version, Inno AppId, and an app-data sentinel. Use the same isolated staging route and trigger the in-app updater. Confirm B′ installs without manual app closure/force-termination, data remains, the candidate EXE is the exact B′ bundle file, AppId/version are correct, and Windows reports the expected `NotSigned` status/SmartScreen warning risk.
4. Record OS/device, exact A/B artifact SHA-256, workflow run IDs, staging-route method (no credentials), results, and any redacted logs. Also test unavailable feed, malformed manifest, wrong channel, invalid signature, wrong hash/size, rollback version, and unexpected redirects. Any failure is HOLD. No result authorizes production feed publication; owner retains the separate exact-version GO.

The owner performs this device/VM test manually using the checklist above; no emulator/VM result is claimed here. The staging route must preserve the signed candidate manifest bytes and must not mutate the live feed.

**Staging gate:** `UpdaterChannelConfig` fixes production clients to `https://myteam.simogatti.it/updates/version.json`; this branch does not establish an isolated route. Before owner testing, INFRA must confirm a controlled staging method that exercises the actual production app identity, Android/Windows signers, pinned Ed25519 trust, and updater handoff without changing the live feed. QA app identity, signer, key, or feed is not a substitute. A staging-specific client rebuild also fails build-once promotion. Until the route is confirmed, this gate is `HOLD`; do not test against the live feed.

### 6 — Explicit GO and publication plan

For the first production release, the owner reviews the A→B evidence. For each subsequent update, the owner reviews the previous promoted version→new candidate evidence. In either case, the release operator records a separate explicit GO for the exact candidate SHA, version/code, manifest hash, archive hash, and intended publication window. No agent infers GO from “proceed,” a passing workflow, a draft archive, prior QA, or this contract. If any prior phase is not `PASS`, GO is invalid.

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

## Repeatable release-pipeline setup checklist — status from this source-only preparation

| Check | Status | Evidence / owner action |
|---|---|---|
| Workflow is manual-only, accepts only protected `main` and an exact full source SHA before signing jobs, pins Actions by full SHA, and has no feed-publish step | PASS (source review) | `.github/workflows/release-candidate.yml`; no workflow was dispatched |
| Android production package identity and Ed25519 pin/signature validation | PASS (source contract only) | `it.simogatti.myteam`; Infra reports signer custody/backup, but passphrase recovery is still PENDING |
| Windows Authenticode | OWNER-ACCEPTED UNSIGNED | Inno installer check requires `NotSigned`; disclose SmartScreen warning |
| `production-release` Environment main-only restriction/reviewers and required secret names/presence | NOT VERIFIED | Environment policy and secret presence have not been verified; never read or expose values. Owner may confirm presence by name only after independent passphrase recovery |
| Workflow builds / candidate artifacts / candidate validation | NOT RUN | No production-signed workflow dispatch or build in this task |
| Owner Android emulator and Windows VM A→B test | NOT RUN | Owner uses exact candidate artifacts and manual checklist above after INFRA confirms staging; no device test is claimed |
| Exact version assignment, archive, production feed and owner GO | NOT RUN | Candidate version proposal is tentative; no binary/feed publication or production GO |

Owner verification checklist: the GitHub API reports the active `Protect main` ruleset described above; recheck it remains active and scoped only to `main`. Configure and verify `production-release` deployment branches/tags restricted to `main`, and scope production signing secrets to that Environment only. If Environment required-reviewer controls are available, designate the owner; with a sole eligible owner, leave **Prevent self-review** off, or add an independent reviewer before enabling it. Verify required secret-name presence only, never values. The separate exact-version production GO remains mandatory regardless. Verify `github.ref_protected == true` and Environment controls before dispatch. Do not weaken automated workflow gates.

## Current gate ledger (updated 2026-11-12)

| Gate | Status | Evidence / blocker |
|---|---|---|
| Production Android ID and Windows Inno AppId policy | PASS (decision) | `RELEASE-BASELINE.md`, Gradle and Inno script; first prod distribution still not made |
| Android production JKS and public certificate fingerprint | REPORTED COMPLETE; recovery HOLD | Infra reports the existing JKS and fingerprint `2d3f30b82fef2d77a5f0f4077bb2a69b1be18d49426717925ffa579d2a1bed5`; independent passphrase-recovery verification remains PENDING |
| Windows Authenticode | OWNER-ACCEPTED UNSIGNED | Explicit unsigned-distribution acknowledgement is required; SmartScreen/unknown-publisher warning risk; no Authenticode verification is claimed |
| Native licensing/compliance review | DEFERRED — NOT ASSESSED | Known debt; no compliance statement or attestation |
| Ed25519 signer matching the updated client pin; custody/backup and recovery | PARTIAL; recovery HOLD | Infra reports custody and backup verified in its private runbook for public key `b7cb644d4d633d2def2e557cdd13382cc6b431292425d4b9`; independent passphrase recovery remains PENDING |
| Workflow dispatch bootstrap on default branch | PASS (file presence only) | Workflow file exists on `main`; candidate source remains exact protected `main` only |
| Main protection | PASS (GitHub API ruleset read) | Active `Protect main` ruleset targets exactly `refs/heads/main`, prevents deletion/non-fast-forward updates, requires linear history, and has no bypass actors |
| Immutable GitHub Action dependency pins | PASS (source review only) | release workflow actions are pinned to full commit SHAs; repository settings and upstream action behavior are not verified |
| Production-signer isolated staging feed and true A→B test | HOLD | client uses fixed production manifest URL; no matching Infra contract available at the given local path |
| Candidate workflow/build/sign/archive | NOT RUN | only source/static inspection this task; workflow is manual, uploads 90-day artifacts |
| Durable candidate archive + independent backup + restore drill | NOT RUN | no candidate built or archive created |
| Production Route/PVC/UID/ingress/publisher + external smoke | NOT RUN | no server access or deployment in this task |
| Owner's exact-version production GO | NOT GIVEN | required separately after all gates pass |

## Release evidence record template

Create one release record per candidate with: version/name/code/prior code; repository/ref/full commit; workflow run ID and conclusion; Flutter/JDK/runner/Inno versions; Android package ID and verified signer SHA-256; Windows AppId/version and `unsigned_owner_accepted` status (no Authenticode fingerprint); `native_license_compliance_status: deferred_not_assessed`; pinned Ed25519 key identifier (public hex only); `version.json` and `.sig` hashes; APK/EXE sizes and SHA-256; `SHA256SUMS`; archive hash and both backup references; A→B Android/Windows device/OS results and data-retention sentinel; security negative-test results; GO record; Infra target/UTC/pointer hashes; external smoke statuses/headers; rollback readiness and final state (`candidate`, `archived`, `staged`, `published`, `rolled_back`). Every item not actually observed must say `NOT RUN` or `NOT VERIFIED`; do not claim native license/compliance clearance.
