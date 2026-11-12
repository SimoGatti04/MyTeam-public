import 'dart:convert';
import '../crypto_verifier.dart';

/// Piattaforme supportate per gli aggiornamenti
enum UpdatePlatform {
  android,
  windows,
  macos,
  unknown;

  static UpdatePlatform fromString(String val) {
    switch (val.toLowerCase()) {
      case 'android':
        return UpdatePlatform.android;
      case 'windows':
        return UpdatePlatform.windows;
      case 'macos':
        return UpdatePlatform.macos;
      default:
        return UpdatePlatform.unknown;
    }
  }
}

/// Rappresenta un singolo artefatto di aggiornamento per piattaforma
class UpdateArtifact {
  final String url;
  final String sha256;
  final int sizeBytes;
  final String? signature; // Firma crittografica facoltativa aggiuntiva per il file binario

  UpdateArtifact({
    required this.url,
    required this.sha256,
    required this.sizeBytes,
    this.signature,
  });

  factory UpdateArtifact.fromJson(Map<String, dynamic> json) {
    final rawUrl = json['url'] as String? ?? '';
    // Sicurezza: obbligo di validazione URL secondo criteri rigorosi (HTTPS, host consentiti)
    if (!CryptoVerifier.isAllowedArtifactUrl(rawUrl)) {
      throw FormatException('L\'URL dell\'artefatto non rispetta i vincoli di sicurezza: $rawUrl');
    }

    final rawSha = json['sha256'] as String? ?? '';
    if (rawSha.trim().length != 64) {
      throw FormatException('SHA-256 dell\'artefatto non valido o mancante: $rawSha');
    }

    return UpdateArtifact(
      url: rawUrl,
      sha256: rawSha.trim().toLowerCase(),
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      signature: json['signature'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'sha256': sha256,
      'size_bytes': sizeBytes,
      if (signature != null) 'signature': signature,
    };
  }
}

/// Manifest di aggiornamento version.json
class UpdateManifest {
  final String versionName;
  final int versionCode;
  final String releaseDate;
  final String changelog;
  final bool mandatory;
  final int minSupportedVersionCode;
  final String? manifestSignature; // Firma detached Ed25519 (se incorporata o letta da header/.sig)
  final Map<String, UpdateArtifact> platforms;

  UpdateManifest({
    required this.versionName,
    required this.versionCode,
    required this.releaseDate,
    required this.changelog,
    this.mandatory = false,
    this.minSupportedVersionCode = 1,
    this.manifestSignature,
    required this.platforms,
  });

  factory UpdateManifest.fromJson(Map<String, dynamic> json, {String? detachedSignature}) {
    final rawPlatforms = json['platforms'] as Map<String, dynamic>? ?? {};
    final platformsMap = <String, UpdateArtifact>{};
    rawPlatforms.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        platformsMap[key] = UpdateArtifact.fromJson(value);
      }
    });

    return UpdateManifest(
      versionName: json['version_name'] as String? ?? '',
      versionCode: (json['version_code'] as num?)?.toInt() ?? 0,
      releaseDate: json['release_date'] as String? ?? '',
      changelog: json['changelog'] as String? ?? '',
      mandatory: json['mandatory'] as bool? ?? false,
      minSupportedVersionCode: (json['min_supported_version_code'] as num?)?.toInt() ?? 1,
      manifestSignature: detachedSignature ?? (json['signature'] as String?),
      platforms: platformsMap,
    );
  }

  static UpdateManifest fromRawJson(String str, {String? detachedSignature}) =>
      UpdateManifest.fromJson(json.decode(str) as Map<String, dynamic>, detachedSignature: detachedSignature);

  UpdateArtifact? getArtifactForPlatform(String platformName) {
    return platforms[platformName.toLowerCase()];
  }
}
