# Third-party licenses and notices

This inventory records package metadata and notice files verified in the locked dependency cache. It is not a legal clearance or a complete inventory of every native binary in a distributable.

## Verified package notices

| Package | Locked version | Included notice | Verified scope |
| --- | --- | --- | --- |
| `ffmpeg_kit_flutter_new` | 4.1.0 | `assets/licenses/ffmpeg_kit_flutter_new/LICENSE` (LGPLv3 text) and `LICENSE.GPLv3` (GPLv3 text) | Package supplies distinct LGPL and GPL license texts. Its Android/iOS/macOS native distribution is Full-GPL; the Android package includes FFmpeg GPL components including x264, x265 and vid.stab. |
| `media_kit_libs_windows_video` | 1.0.11 | `assets/licenses/media_kit_libs_windows_video/LICENSE` (MIT text) | Verified wrapper-package notice only. The package pins `mpv-dev-x86_64-20230924-git-652a1dd.7z`; the native libmpv and its build options are not verified by this notice. |

The Flutter-generated `NOTICES.Z` includes package metadata notices, but does not replace the separate FFmpegKit `LICENSE.GPLv3`; both FFmpegKit texts are explicitly packaged here. On Windows, the Inno installer places the project GPL license and these package notices under `{app}\licenses` as well as retaining Flutter assets.

## Separate Windows tool

Windows compression invokes FFmpeg installed separately through the documented WinGet workflow; that external executable is not included in the MyTeam installer. The referenced Gyan FFmpeg distribution is GPLv3. Users/operators must obtain and comply with the terms and corresponding-source requirements applicable to their separately installed build.

## Deferred native audit — known debt, not compliance clearance

By owner decision, the native third-party binary provenance/license audit is deferred until after launch. Its status remains **NOT VERIFIED**; this inventory is not a legal clearance and does not establish compliance for any binary. Do not treat the verified wrapper notices as proof of native redistribution compliance. The deferred audit must record exact shipped binaries and provenance; identify the libmpv build configuration and applicable license terms; verify bundled graphics/runtime notices and redistribution permissions; and determine applicable source, relinking, or source-offer obligations for the exact builds. The final Windows installer payload has not been extracted/verified, and Android/iOS/macOS native payloads have not been audited against release artifacts. Track and complete this work after launch; do not describe the native scope as compliant before evidence is recorded.

## Reproduction metadata

The notice files above were copied verbatim from the pub cache packages matching `pubspec.lock`. Their source-file SHA-256 digests were verified against the packaged copies during preparation. Package updates require repeating that comparison and reviewing the new package/native payload metadata; do not update dependencies as part of this notice-only record.
