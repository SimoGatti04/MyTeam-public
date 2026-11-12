# Production release baseline

**Status:** the adopted production identities and security requirements below are the project baseline; this document does not claim that production credentials, certificates, or a production candidate have been provisioned. The canonical [production release contract](PRODUCTION-RELEASE.md) is the sole execution procedure and current HOLD ledger.

## Adopted client identities

- Production Android application ID: `it.simogatti.myteam`. QA remains a distinct application identity. Never install or promote a QA-signed package as production.
- Android production signing identity must be stable across every version. The actual certificate fingerprint is not yet recorded/verified; release remains HOLD until the built APK matches the owner-approved public fingerprint.
- Windows installer identity remains the stable Inno Setup AppId declared in `windows/installer/MyTeam-Setup.iss`; per-user installation and user data must survive upgrades. By owner decision, Authenticode is not required for launch; unsigned installers may show Windows trust warnings, and no trusted publisher identity is claimed.
- Production updater manifests use the production Ed25519 public key pinned in `lib/core/services/updater/release_key_pin.dart`. QA uses a different trust pin and feed path. The public key is an identity anchor, not a credential; private signing material is not documented here.
- Production client updates use the public HTTPS service domain configured in source. QA endpoints and feed content remain separate.

## Release invariants

1. Version names and platform codes increase monotonically; A and B use the same platform application/installer identity and signing certificate.
2. Build once from a reviewed immutable commit, verify the exact APK/installer signatures and hashes, archive exact bytes, and test the signed candidate before a separate owner GO.
3. Manifest signatures cover the exact raw manifest bytes. Client signature, channel, version, artifact hash, and platform checks fail closed. Never silently rotate or replace trust identities.
4. The Windows updater handoff must close the running process gracefully before replacement, preserve user data, and be verified on a Windows VM. Android data retention must be verified on an emulator/device.
5. QA artifacts or credentials do not substitute for production identity or production certification.

## Current release holds

- Production Android signing identity/fingerprint has not been verified in this baseline.
- Authenticode is intentionally not required for launch by owner decision; no trusted Windows publisher identity is claimed, and unsigned-installer warnings are possible.
- A production-identity A′→B′ end-to-end test and exact-byte archive/restore evidence are required before release GO.
- No production publication or user distribution is authorized by this baseline.

This file intentionally omits secret-setting identifiers, key locations, credential custody procedures, owner paths, and private infrastructure details. Consult only the canonical contract and owner-authorized restricted operational records; do not place those details in public source.
