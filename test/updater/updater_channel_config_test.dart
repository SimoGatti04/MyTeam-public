import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter_test/flutter_test.dart';
import 'package:myteam/core/constants/app_constants.dart';
import 'package:myteam/core/services/updater/crypto_verifier.dart';
import 'package:myteam/core/services/updater/models/update_state.dart';
import 'package:myteam/core/services/updater/update_service.dart';
import 'package:myteam/core/services/updater/updater_channel_config.dart';

void main() {
  const productionPublicKey =
      'b7cb644d4d633d2def2e557cdd13382cc6b431292425d4b9f3cab0ba12c139b9';
  const qaPublicKey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('production resolver keeps the pinned release URL and key', () {
    final config = UpdaterChannelConfig.resolve(
      qaEnabled: false,
      qaPublicKeyHex: 'not-a-key',
      platform: TargetPlatform.android,
    );

    expect(config.isValid, isTrue);
    expect(config.isQa, isFalse);
    expect(config.manifestUrl, '${AppConstants.baseUrl}/updates/version.json');
    expect(config.publicKeyHex, productionPublicKey);
    expect(config.publicKeyHex, CryptoVerifier.defaultReleasePublicKeyHex);
  });

  test('production and QA manifest signing identities remain separate', () {
    final production = UpdaterChannelConfig.resolve(
      qaEnabled: false,
      qaPublicKeyHex: qaPublicKey,
      platform: TargetPlatform.android,
    );
    final qa = UpdaterChannelConfig.resolve(
      qaEnabled: true,
      qaPublicKeyHex: qaPublicKey,
      platform: TargetPlatform.android,
    );

    expect(
      production.manifestUrl,
      '${AppConstants.baseUrl}/updates/version.json',
    );
    expect(
      qa.manifestUrl,
      '${AppConstants.baseUrl}/updates/qa/android/version.json',
    );
    expect(production.publicKeyHex, CryptoVerifier.defaultReleasePublicKeyHex);
    expect(qa.publicKeyHex, qaPublicKey);
    expect(qa.publicKeyHex, isNot(production.publicKeyHex));
  });

  test('production rejects a manifest signed only by an ephemeral QA key', () {
    final keyPair = ed.generateKey();
    final qaKeyHex = hex.encode(keyPair.publicKey.bytes);
    final payload = utf8.encode('{"version_name":"0.2.1","version_code":3}');
    final signatureHex = hex.encode(ed.sign(keyPair.privateKey, payload));
    final production = UpdaterChannelConfig.resolve(
      qaEnabled: false,
      qaPublicKeyHex: qaKeyHex,
      platform: TargetPlatform.android,
    );

    expect(
      CryptoVerifier.verifyManifestEd25519(
        manifestBytes: payload,
        signatureHex: signatureHex,
        publicKeyHex: qaKeyHex,
      ),
      isTrue,
    );
    expect(
      CryptoVerifier.verifyManifestEd25519(
        manifestBytes: payload,
        signatureHex: signatureHex,
        publicKeyHex: production.publicKeyHex,
      ),
      isFalse,
    );
  });

  test('release package and installer identities stay stable', () {
    final androidGradle = File(
      'android/app/build.gradle.kts',
    ).readAsStringSync();
    final installer = File(
      'windows/installer/MyTeam-Setup.iss',
    ).readAsStringSync();
    final qaWorkflow = File(
      '.github/workflows/qa-updater-build.yml',
    ).readAsStringSync();

    expect(androidGradle, contains('"qa" -> "com.example.myteam_video_app"'));
    expect(androidGradle, contains('else -> "it.simogatti.myteam"'));
    expect(androidGradle, contains('applicationId = androidApplicationId'));
    expect(qaWorkflow, contains('MYTEAM_ANDROID_SIGNING_CHANNEL: qa'));
    expect(qaWorkflow, contains('--dart-define=MYTEAM_UPDATER_QA=true'));
    expect(qaWorkflow, contains("name='com.example.myteam_video_app'"));
    expect(
      installer,
      contains('AppId={{9B7E3E5C-62E8-4DA4-8FB7-F58552309AA2}'),
    );
    expect(
      installer,
      contains(r'DefaultDirName={localappdata}\Programs\{#MyAppName}'),
    );
    expect(installer, contains('CloseApplications=yes'));
    expect(installer, contains('RestartApplications=no'));
  });

  test('QA resolver selects only fixed Android and Windows feed paths', () {
    for (final entry in <(TargetPlatform, String)>[
      (TargetPlatform.android, 'android'),
      (TargetPlatform.windows, 'windows'),
    ]) {
      final config = UpdaterChannelConfig.resolve(
        qaEnabled: true,
        qaPublicKeyHex: qaPublicKey,
        platform: entry.$1,
      );
      final uri = Uri.parse(config.manifestUrl);

      expect(config.isValid, isTrue);
      expect(config.isQa, isTrue);
      expect(uri.scheme, 'https');
      expect(uri.host, 'myteam.simogatti.it');
      expect(uri.path, '/updates/qa/${entry.$2}/version.json');
      expect(CryptoVerifier.isAllowedEndpointUrl(uri), isTrue);
      expect(
        CryptoVerifier.isAllowedEndpointUrl(
          Uri.parse(
            'https://myteam.simogatti.it.evil/updates/qa/${entry.$2}/version.json',
          ),
        ),
        isFalse,
      );
      expect(
        CryptoVerifier.isAllowedEndpointUrl(uri.replace(scheme: 'http')),
        isFalse,
      );
      expect(
        CryptoVerifier.isAllowedEndpointUrl(uri.replace(port: 444)),
        isFalse,
      );
      expect(config.publicKeyHex, qaPublicKey);
    }
  });

  test(
    'missing, malformed, reused release key and unsupported platform fail closed',
    () {
      final invalidCases = <UpdaterChannelConfig>[
        UpdaterChannelConfig.resolve(
          qaEnabled: true,
          qaPublicKeyHex: '',
          platform: TargetPlatform.android,
        ),
        UpdaterChannelConfig.resolve(
          qaEnabled: true,
          qaPublicKeyHex: 'xyz',
          platform: TargetPlatform.windows,
        ),
        UpdaterChannelConfig.resolve(
          qaEnabled: true,
          qaPublicKeyHex: CryptoVerifier.defaultReleasePublicKeyHex,
          platform: TargetPlatform.android,
        ),
        UpdaterChannelConfig.resolve(
          qaEnabled: true,
          qaPublicKeyHex: qaPublicKey,
          platform: TargetPlatform.linux,
        ),
      ];

      for (final config in invalidCases) {
        expect(config.isValid, isFalse);
        expect(config.configurationError, isNotNull);
        expect(config.publicKeyHex, isEmpty);
      }
    },
  );

  test(
    'QA service pins its key and rejects runtime key or feed replacement',
    () async {
      var requestCount = 0;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requestCount++;
              handler.next(options);
            },
          ),
        );
      final config = UpdaterChannelConfig.resolve(
        qaEnabled: true,
        qaPublicKeyHex: qaPublicKey,
        platform: TargetPlatform.android,
      );
      final service = UpdateService.createForTesting(
        dio: dio,
        channelConfig: config,
      );

      expect(service.manifestUrl, config.manifestUrl);
      expect(service.isQaChannel, isTrue);
      expect(service.manifestPublicKeyHexForTesting, qaPublicKey);
      expect(
        () => service.setManifestPublicKey(List.filled(64, 'b').join()),
        throwsStateError,
      );
      expect(
        await service.checkForUpdates(
          customManifestUrl: '${AppConstants.baseUrl}/updates/version.json',
        ),
        isFalse,
      );
      expect(requestCount, 0);
      expect(service.state.failureKind, UpdateFailureKind.security);
    },
  );

  test(
    'invalid QA key fails before network even when signature bypass is requested',
    () async {
      var requestCount = 0;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requestCount++;
              handler.next(options);
            },
          ),
        );
      final config = UpdaterChannelConfig.resolve(
        qaEnabled: true,
        qaPublicKeyHex: '',
        platform: TargetPlatform.windows,
      );
      final service = UpdateService.createForTesting(
        dio: dio,
        channelConfig: config,
      );

      expect(
        await service.checkForUpdates(skipSignatureVerification: true),
        isFalse,
      );
      expect(requestCount, 0);
      expect(service.state.status, UpdateStatus.failed);
      expect(service.state.failureKind, UpdateFailureKind.security);
      expect(service.state.errorMessage, contains('canale QA'));
    },
  );
}
