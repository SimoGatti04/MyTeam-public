import 'package:flutter/foundation.dart';

import '../../constants/app_constants.dart';
import 'release_key_pin.dart';

/// Immutable updater feed/key selection derived from compile-time build defines.
/// QA builds can only select fixed platform paths on the pinned HTTPS origin.
class UpdaterChannelConfig {
  static const bool _qaEnabled = bool.fromEnvironment(
    'MYTEAM_UPDATER_QA',
    defaultValue: false,
  );
  static const String _qaPublicKeyHex = String.fromEnvironment(
    'MYTEAM_UPDATER_QA_PUBLIC_KEY_HEX',
  );

  final bool isQa;
  final String manifestUrl;
  final String publicKeyHex;
  final String? configurationError;

  const UpdaterChannelConfig._({
    required this.isQa,
    required this.manifestUrl,
    required this.publicKeyHex,
    this.configurationError,
  });

  bool get isValid => configurationError == null;

  factory UpdaterChannelConfig.fromBuildDefines() => resolve(
    qaEnabled: _qaEnabled,
    qaPublicKeyHex: _qaPublicKeyHex,
    platform: defaultTargetPlatform,
  );

  /// Pure resolver for unit tests and build-time QA configuration validation.
  /// Runtime selection uses only the compile-time constants above.
  static UpdaterChannelConfig resolve({
    required bool qaEnabled,
    required String qaPublicKeyHex,
    required TargetPlatform platform,
  }) {
    final productionUrl = '${AppConstants.baseUrl}/updates/version.json';
    if (!qaEnabled) {
      return UpdaterChannelConfig._(
        isQa: false,
        manifestUrl: productionUrl,
        publicKeyHex: defaultReleasePublicKeyHex,
      );
    }

    final platformPath = switch (platform) {
      TargetPlatform.android => 'android',
      TargetPlatform.windows => 'windows',
      _ => null,
    };
    if (platformPath == null) {
      return const UpdaterChannelConfig._(
        isQa: true,
        manifestUrl: '',
        publicKeyHex: '',
        configurationError:
            'QA updater is supported only on Android and Windows.',
      );
    }

    final qaUrl =
        '${AppConstants.baseUrl}/updates/qa/$platformPath/version.json';
    final key = qaPublicKeyHex.trim().toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(key)) {
      return UpdaterChannelConfig._(
        isQa: true,
        manifestUrl: qaUrl,
        publicKeyHex: '',
        configurationError: 'QA Ed25519 public key is missing or malformed.',
      );
    }
    if (key == defaultReleasePublicKeyHex.toLowerCase()) {
      return UpdaterChannelConfig._(
        isQa: true,
        manifestUrl: qaUrl,
        publicKeyHex: '',
        configurationError: 'QA key must be distinct from the release key.',
      );
    }

    final uri = Uri.parse(qaUrl);
    if (uri.scheme != 'https' ||
        uri.host != 'myteam.simogatti.it' ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443)) {
      return const UpdaterChannelConfig._(
        isQa: true,
        manifestUrl: '',
        publicKeyHex: '',
        configurationError: 'QA updater origin is not the pinned HTTPS origin.',
      );
    }

    return UpdaterChannelConfig._(
      isQa: true,
      manifestUrl: qaUrl,
      publicKeyHex: key,
    );
  }
}
