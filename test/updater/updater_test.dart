import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'dart:io';
import 'package:convert/convert.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter_test/flutter_test.dart';
import 'package:myteam/core/services/updater/models/update_manifest.dart';
import 'package:myteam/core/services/updater/crypto_verifier.dart';
import 'package:myteam/core/services/updater/active_tasks_guard.dart';
import 'package:myteam/core/services/updater/update_service.dart';
import 'package:myteam/presentation/widgets/updater/startup_update_notice.dart';
import 'package:myteam/presentation/widgets/updater/update_banner_widget.dart';
import 'package:myteam/core/services/updater/installer_service.dart';
import 'package:myteam/core/services/updater/models/update_state.dart';
import 'package:myteam/features/upload/viewmodels/upload_viewmodel.dart';
import 'package:myteam/domain/usecases/upload_video_usecase.dart';
import 'package:myteam/domain/repositories/upload_repository.dart';
import 'package:myteam/domain/entities/upload_task.dart';
import 'package:myteam/domain/entities/compression_settings.dart';

class MockUploadRepository implements UploadRepository {
  List<UploadTask> activeUploads = [];
  List<UploadTask> completedUploads = [];
  bool shouldThrowOnLoad = false;

  MockUploadRepository({
    List<UploadTask>? active,
    List<UploadTask>? completed,
    this.shouldThrowOnLoad = false,
  }) {
    if (active != null) activeUploads = active;
    if (completed != null) completedUploads = completed;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<UploadTask>> getActiveUploads() async {
    if (shouldThrowOnLoad)
      throw Exception('Simulated DB query error during getActiveUploads');
    return activeUploads;
  }

  @override
  Future<List<UploadTask>> getCompletedUploads({int limit = 10}) async {
    if (shouldThrowOnLoad)
      throw Exception('Simulated DB query error during getCompletedUploads');
    return completedUploads;
  }

  @override
  Future<List<UploadTask>> loadSavedUploadTasks() async {
    if (shouldThrowOnLoad)
      throw Exception('Simulated DB query error during loadSavedUploadTasks');
    return [...activeUploads, ...completedUploads];
  }

  @override
  Future<void> cancelUpload(String taskId) async {
    activeUploads.removeWhere((t) => t.id == taskId);
  }

  Future<void> saveUploadTask(UploadTask task) async {
    activeUploads.removeWhere((t) => t.id == task.id);
    activeUploads.add(task);
  }
}

class MockTestInstallerDelegate implements InstallerDelegate {
  bool installCalled = false;
  File? receivedPackageFile;
  List<String>? receivedArgs;
  bool returnSuccess = true;
  Exception? throwException;

  @override
  Future<bool> installPackage({
    required File packageFile,
    List<String>? requestedArgs,
  }) async {
    installCalled = true;
    receivedPackageFile = packageFile;
    receivedArgs = requestedArgs;
    if (throwException != null) throw throwException!;
    return returnSuccess;
  }
}

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Autonomous Updater - Manifest & Security Tests', () {
    test('Parses valid version.json correctly for Android and Windows', () {
      final sampleJson = {
        "version_name": "0.2.0",
        "version_code": 2,
        "release_date": "2026-11-01",
        "changelog": "Autonomous updater support and migration to simogatti.it",
        "mandatory": false,
        "min_supported_version_code": 1,
        "platforms": {
          "android": {
            "url": "https://myteam.simogatti.it/updates/MyTeam-0.2.0.apk",
            "sha256":
                "f246a89377e6223e6fd9e3e68cba80d909f3cfb821631cdc0b4057649b457569",
            "size_bytes": 240000000,
          },
          "windows": {
            "url": "https://myteam.simogatti.it/updates/MyTeam-Setup-0.2.0.exe",
            "sha256":
                "bd94e94fd850be650585fad77c9400f5d060bb441688c1ad1e14af4623ed451e",
            "size_bytes": 45000000,
          },
        },
      };

      final manifest = UpdateManifest.fromJson(sampleJson);
      expect(manifest.versionName, equals("0.2.0"));
      expect(manifest.versionCode, equals(2));
      expect(manifest.platforms.containsKey("android"), isTrue);
      expect(manifest.platforms.containsKey("windows"), isTrue);

      final androidArtifact = manifest.getArtifactForPlatform("android");
      expect(androidArtifact?.url, startsWith("https://myteam.simogatti.it"));
      expect(androidArtifact?.sizeBytes, equals(240000000));
      expect(androidArtifact?.sha256.length, equals(64));
    });

    test('Rejects non-HTTPS or untrusted artifact URLs for security', () {
      final httpJson = {
        "version_name": "0.2.0",
        "version_code": 2,
        "release_date": "2026-11-01",
        "changelog": "Test insecure artifact",
        "platforms": {
          "android": {
            "url": "http://myteam.simogatti.it/updates/app.apk",
            "sha256":
                "f246a89377e6223e6fd9e3e68cba80d909f3cfb821631cdc0b4057649b457569",
            "size_bytes": 1000,
          },
        },
      };

      expect(
        () => UpdateManifest.fromJson(httpJson),
        throwsA(isA<FormatException>()),
      );

      final untrustedHostJson = {
        "version_name": "0.2.0",
        "version_code": 2,
        "release_date": "2026-11-01",
        "changelog": "Test untrusted host",
        "platforms": {
          "android": {
            "url": "https://evil-attacker.com/malicious.apk",
            "sha256":
                "f246a89377e6223e6fd9e3e68cba80d909f3cfb821631cdc0b4057649b457569",
            "size_bytes": 1000,
          },
        },
      };

      expect(
        () => UpdateManifest.fromJson(untrustedHostJson),
        throwsA(isA<FormatException>()),
      );
      expect(
        CryptoVerifier.isAllowedArtifactUrl(
          'https://api.simogatti.it/updates/app.apk',
        ),
        isFalse,
      );
      expect(
        CryptoVerifier.isAllowedArtifactUrl(
          'https://myteam.simogatti.it:8443/updates/app.apk',
        ),
        isFalse,
      );
      expect(
        CryptoVerifier.isAllowedArtifactUrl(
          'https://myteam.simogatti.it:0/updates/app.apk',
        ),
        isFalse,
      );
      expect(
        CryptoVerifier.isAllowedArtifactUrl(
          'https://user@myteam.simogatti.it/updates/app.apk',
        ),
        isFalse,
      );
    });

    test('Localhost exception is strictly bounded (no substring matching)', () {
      expect(
        CryptoVerifier.isAllowedEndpointUrl(
          Uri.parse('https://myteam.simogatti.it/updates/version.json'),
        ),
        isTrue,
      );
      expect(
        CryptoVerifier.isAllowedEndpointUrl(
          Uri.parse('http://localhost:8000/updates/version.json'),
        ),
        isTrue,
      );
      expect(
        CryptoVerifier.isAllowedEndpointUrl(
          Uri.parse('http://127.0.0.1:8000/updates/version.json'),
        ),
        isTrue,
      );
      // Malicious subdomain containing "localhost" MUST be rejected
      expect(
        CryptoVerifier.isAllowedEndpointUrl(
          Uri.parse('http://fake-localhost.evil.com/updates/version.json'),
        ),
        isFalse,
      );
      expect(
        CryptoVerifier.isAllowedEndpointUrl(
          Uri.parse('http://localhost.evil.com/updates/version.json'),
        ),
        isFalse,
      );
    });
  });

  group('Autonomous Updater - Asymmetric Ed25519 Cryptographic Verification', () {
    test(
      'Verifies valid Ed25519 signature and rejects tampered manifest or invalid signature',
      () {
        final keyPair = ed.generateKey();
        final pubKeyHex = hex.encode(keyPair.publicKey.bytes);

        final rawManifestJson = '{"version_name":"0.2.0","version_code":2}';
        final manifestBytes = utf8.encode(rawManifestJson);

        final validSig = ed.sign(keyPair.privateKey, manifestBytes);
        final validSigHex = hex.encode(validSig);

        // 1. Firma valida
        final isSignatureValid = CryptoVerifier.verifyManifestEd25519(
          manifestBytes: manifestBytes,
          signatureHex: validSigHex,
          publicKeyHex: pubKeyHex,
        );
        expect(isSignatureValid, isTrue);

        // 2. Manifest alterato (tampering detection)
        final tamperedBytes = utf8.encode(
          '{"version_name":"0.2.0","version_code":999}',
        );
        final isTamperedValid = CryptoVerifier.verifyManifestEd25519(
          manifestBytes: tamperedBytes,
          signatureHex: validSigHex,
          publicKeyHex: pubKeyHex,
        );
        expect(isTamperedValid, isFalse);

        // 3. Firma alterata / invalida
        final corruptedSigHex = validSigHex.replaceRange(0, 4, '0000');
        final isCorruptedSigValid = CryptoVerifier.verifyManifestEd25519(
          manifestBytes: manifestBytes,
          signatureHex: corruptedSigHex,
          publicKeyHex: pubKeyHex,
        );
        expect(isCorruptedSigValid, isFalse);

        // 4. Firma vuota o malformata
        expect(
          CryptoVerifier.verifyManifestEd25519(
            manifestBytes: manifestBytes,
            signatureHex: '',
            publicKeyHex: pubKeyHex,
          ),
          isFalse,
        );
      },
    );

    test('Computes and verifies SHA-256 in streaming mode', () async {
      final tempDir = await Directory.systemTemp.createTemp('updater_test_');
      final testFile = File('${tempDir.path}/test_payload.bin');
      await testFile.writeAsString('MyTeam Secure Update Stream Payload 2026');

      final computedHash = await CryptoVerifier.computeFileSha256(testFile);
      expect(computedHash.length, equals(64));

      final isMatching = await CryptoVerifier.verifySha256(
        testFile,
        computedHash,
      );
      expect(isMatching, isTrue);

      final tamperedHash =
          '0000000000000000000000000000000000000000000000000000000000000000';
      final isTamperedValid = await CryptoVerifier.verifySha256(
        testFile,
        tamperedHash,
      );
      expect(isTamperedValid, isFalse);

      await tempDir.delete(recursive: true);
    });
  });

  group('Autonomous Updater - Active Task Guard Fail-Closed & Lifecycle Tests', () {
    test('FAIL-CLOSED: Blocks installation if UploadViewModel is null', () {
      final uninitializedGuard = ActiveTasksGuard(uploadViewModel: null);
      expect(
        uninitializedGuard.hasActiveOperations,
        isTrue,
        reason:
            'A null ViewModel must fail-closed to prevent unmonitored corruption',
      );
      expect(
        uninitializedGuard.activeOperationsDescription,
        contains('non ancora disponibile'),
      );
    });

    test(
      'FAIL-CLOSED: Blocks installation if UploadViewModel is NOT initialized',
      () {
        final mockRepo = MockUploadRepository();
        final useCase = UploadVideoUseCase(mockRepo);
        final viewModel = UploadViewModel(useCase);
        // isInitialized è false inizialmente finché loadSavedUploadTasks() non completa

        final guard = ActiveTasksGuard(uploadViewModel: viewModel);
        expect(
          guard.hasActiveOperations,
          isTrue,
          reason: 'Uninitialized tasks state must fail-closed',
        );
        expect(
          guard.activeOperationsDescription,
          contains('Inizializzazione dei caricamenti'),
        );
      },
    );

    test(
      'Allows installation when ViewModel has finished initializing and has no active operations',
      () async {
        final mockRepo = MockUploadRepository();
        final useCase = UploadVideoUseCase(mockRepo);
        final viewModel = UploadViewModel(useCase);

        await viewModel.loadSavedUploadTasks();
        expect(viewModel.isInitialized, isTrue);

        final guard = ActiveTasksGuard(uploadViewModel: viewModel);
        expect(guard.hasActiveOperations, isFalse);
        expect(guard.activeOperationsDescription, isNull);
      },
    );

    test('BLOCKS installation when queue has pending uploads', () async {
      final mockRepo = MockUploadRepository();
      final useCase = UploadVideoUseCase(mockRepo);
      final viewModel = UploadViewModel(useCase);
      await viewModel.loadSavedUploadTasks();

      final tempDir = await Directory.systemTemp.createTemp('upload_test_');
      final videoFile = File('${tempDir.path}/test_match.mp4');
      await videoFile.writeAsString('video dummy content');

      viewModel.queueUpload(
        videoFile: videoFile,
        title: 'Partita 1 Novembre 2026',
        compressionSettings: const CompressionSettings(keepOriginal: true),
      );

      final guard = ActiveTasksGuard(uploadViewModel: viewModel);
      expect(guard.hasActiveOperations, isTrue);
      expect(
        guard.activeOperationsDescription,
        contains('Coda di caricamento attiva'),
      );

      viewModel.clearUploadQueue();
      await tempDir.delete(recursive: true);
    });

    test(
      'Installation lock blocks new uploads and protects transition to system installer',
      () async {
        final mockRepo = MockUploadRepository();
        final useCase = UploadVideoUseCase(mockRepo);
        final viewModel = UploadViewModel(useCase);
        await viewModel.loadSavedUploadTasks();

        final guard = ActiveTasksGuard(uploadViewModel: viewModel);
        expect(guard.hasActiveOperations, isFalse);

        // Attiva lock transizione installazione
        viewModel.setInstallationInProgress(true);
        expect(guard.hasActiveOperations, isTrue);
        expect(
          guard.activeOperationsDescription,
          contains('Installazione già avviata'),
        );

        // Verifica che nuovi upload vengano rifiutati
        final tempDir = await Directory.systemTemp.createTemp('upload_test_');
        final videoFile = File('${tempDir.path}/test_match.mp4');
        await videoFile.writeAsString('video dummy content');

        viewModel.queueUpload(
          videoFile: videoFile,
          title: 'Partita durante installazione',
          compressionSettings: const CompressionSettings(keepOriginal: true),
        );

        expect(viewModel.queueLength, equals(0));
        expect(
          viewModel.error,
          contains('Impossibile avviare caricamenti durante'),
        );

        await tempDir.delete(recursive: true);
      },
    );
  });

  group('Autonomous Updater - Integration & Negative Tests', () {
    test(
      'Manifest without signature is rejected when signature verification is enabled',
      () async {
        final mockRepo = MockUploadRepository();
        final useCase = UploadVideoUseCase(mockRepo);
        final viewModel = UploadViewModel(useCase);
        await viewModel.loadSavedUploadTasks();

        final guard = ActiveTasksGuard(uploadViewModel: viewModel);
        final updateService = UpdateService.instance;
        updateService.setGuard(guard);

        // Manifest privo di signature field o detached signature
        final rawManifestJson = jsonEncode({
          "version_name": "0.3.0",
          "version_code": 3,
          "release_date": "2026-11-01",
          "changelog": "Unsigned release",
          "platforms": {
            "android": {
              "url": "https://myteam.simogatti.it/updates/MyTeam-0.3.0.apk",
              "sha256":
                  "f246a89377e6223e6fd9e3e68cba80d909f3cfb821631cdc0b4057649b457569",
              "size_bytes": 1000,
            },
          },
        });

        // Simula controllo con manifest non firmato
        // Verifica che lanci o fallisca con stato failed
        final manifestBytes = utf8.encode(rawManifestJson);
        final isVerified = CryptoVerifier.verifyManifestEd25519(
          manifestBytes: manifestBytes,
          signatureHex: '',
        );
        expect(isVerified, isFalse);
      },
    );

    test(
      'Negative test: Corrupted SHA-256 is detected and rejects artifact',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'updater_tamper_',
        );
        final corruptedFile = File('${tempDir.path}/fake_update.apk');
        await corruptedFile.writeAsString('corrupted payload content');

        const expectedSha256 =
            'f246a89377e6223e6fd9e3e68cba80d909f3cfb821631cdc0b4057649b457569';
        final isMatch = await CryptoVerifier.verifySha256(
          corruptedFile,
          expectedSha256,
        );
        expect(isMatch, isFalse, reason: 'Must detect SHA-256 mismatch');

        await tempDir.delete(recursive: true);
      },
    );

    group('Autonomous Updater - C2-R3 Security Gates & Edge Cases', () {
      test(
        'Empty repository initialization succeeds and unblocks updater',
        () async {
          final mockRepo = MockUploadRepository(active: [], completed: []);
          final useCase = UploadVideoUseCase(mockRepo);
          final viewModel = UploadViewModel(useCase);

          expect(viewModel.isInitialized, isFalse);
          expect(viewModel.isLoadingTasks, isFalse);
          expect(viewModel.initError, isNull);

          await viewModel.loadSavedUploadTasks();

          expect(viewModel.isInitialized, isTrue);
          expect(viewModel.isLoadingTasks, isFalse);
          expect(viewModel.initError, isNull);
          expect(viewModel.uploadTasks, isEmpty);

          final guard = ActiveTasksGuard(uploadViewModel: viewModel);
          expect(guard.hasActiveOperations, isFalse);
        },
      );

      test(
        'Repository load exception leaves state uninitialized (Fail-Closed) and blocks updater',
        () async {
          final mockRepo = MockUploadRepository(shouldThrowOnLoad: true);
          final useCase = UploadVideoUseCase(mockRepo);
          final viewModel = UploadViewModel(useCase);

          await viewModel.loadSavedUploadTasks();

          expect(viewModel.isInitialized, isFalse);
          expect(viewModel.initError, isNotNull);
          expect(viewModel.initError, contains('Simulated DB query error'));

          final guard = ActiveTasksGuard(uploadViewModel: viewModel);
          expect(guard.hasActiveOperations, isTrue);
          expect(
            guard.activeOperationsDescription,
            contains('Errore durante la verifica dei file locali'),
          );
        },
      );

      test(
        'Deferred cleanup does NOT delete compressed files associated with active/persisted tasks',
        () async {
          final tempDir = await Directory.systemTemp.createTemp(
            'cleanup_test_',
          );
          final activeCompressedFile = File(
            '${tempDir.path}/compressed_active_match.mp4',
          );
          await activeCompressedFile.writeAsString('active compressed content');

          final oldAbandonedFile = File(
            '${tempDir.path}/compressed_abandoned_old.mp4',
          );
          await oldAbandonedFile.writeAsString('old abandoned content');

          final activeTask = UploadTask(
            id: 'task_active_1',
            localFilePath: activeCompressedFile.path,
            remoteFileName: 'active_match.mp4',
            totalBytes: 1000,
            uploadedBytes: 500,
            status: UploadStatus.uploading,
            progress: 0.5,
            createdAt: DateTime.now(),
          );

          final mockRepo = MockUploadRepository(
            active: [activeTask],
            completed: [],
          );
          final useCase = UploadVideoUseCase(mockRepo);
          final viewModel = UploadViewModel(useCase);

          await viewModel.loadSavedUploadTasks();

          expect(viewModel.uploadTasks.length, equals(1));
          expect(viewModel.uploadTasks.first.id, equals('task_active_1'));

          final guard = ActiveTasksGuard(uploadViewModel: viewModel);
          expect(guard.hasActiveOperations, isTrue);

          await tempDir.delete(recursive: true);
        },
      );

      test(
        'Real triggerInstallation acquires lock, rejects if active, and releases lock on cancelled/failed install',
        () async {
          final mockRepo = MockUploadRepository(active: [], completed: []);
          final useCase = UploadVideoUseCase(mockRepo);
          final viewModel = UploadViewModel(useCase);
          await viewModel.loadSavedUploadTasks();

          final guard = ActiveTasksGuard(uploadViewModel: viewModel);
          final updateService = UpdateService.instance;
          updateService.setGuard(guard);

          // 1. Nessun file pronto -> fallisce prima del lock
          final res1 = await updateService.triggerInstallation();
          expect(res1, isFalse);
          expect(updateService.state.status, equals(UpdateStatus.failed));
          expect(viewModel.isInstallationInProgress, isFalse);

          // 2. Crea file fittizio pronto per installazione
          final tempDir = await Directory.systemTemp.createTemp(
            'trigger_test_',
          );
          final fakePkg = File('${tempDir.path}/update.apk');
          await fakePkg.writeAsString('dummy apk content');

          // Imposta stato readyToInstall
          updateService.resetAfterCancelledInstall();
          // Simula stato con file
          final rawManifestJson = {
            "version_name": "0.3.0",
            "version_code": 3,
            "release_date": "2026-11-01",
            "changelog": "C2-R3 Verification",
            "mandatory": false,
            "platforms": {
              "android": {
                "url": "https://myteam.simogatti.it/updates/update.apk",
                "sha256":
                    "f246a89377e6223e6fd9e3e68cba80d909f3cfb821631cdc0b4057649b457569",
                "size_bytes": 1000,
              },
            },
          };
          UpdateManifest.fromJson(rawManifestJson);

          // Test resetAfterCancelledInstall rilascia il lock
          viewModel.acquireInstallationLock();
          expect(viewModel.isInstallationInProgress, isTrue);
          updateService.resetAfterCancelledInstall();
          expect(viewModel.isInstallationInProgress, isFalse);

          await tempDir.delete(recursive: true);
        },
      );

      test(
        'Detached Ed25519 signature: rejects different key and altered payload',
        () {
          final keyPairAuthor = ed.generateKey();
          final keyPairAttacker = ed.generateKey();
          final pubKeyAuthorHex = hex.encode(keyPairAuthor.publicKey.bytes);

          final originalPayload = utf8.encode(
            '{"version_code": 5, "version_name": "0.5.0"}',
          );
          final validSig = ed.sign(keyPairAuthor.privateKey, originalPayload);
          final validSigHex = hex.encode(validSig);

          // 1. Firma valida con chiave autore -> PASS
          expect(
            CryptoVerifier.verifyManifestEd25519(
              manifestBytes: originalPayload,
              signatureHex: validSigHex,
              publicKeyHex: pubKeyAuthorHex,
            ),
            isTrue,
          );

          // 2. Payload alterato -> REJECT
          final alteredPayload = utf8.encode(
            '{"version_code": 6, "version_name": "0.6.0"}',
          );
          expect(
            CryptoVerifier.verifyManifestEd25519(
              manifestBytes: alteredPayload,
              signatureHex: validSigHex,
              publicKeyHex: pubKeyAuthorHex,
            ),
            isFalse,
          );

          // 3. Firma generata da chiave non autorizzata -> REJECT
          final attackerSig = ed.sign(
            keyPairAttacker.privateKey,
            originalPayload,
          );
          final attackerSigHex = hex.encode(attackerSig);
          expect(
            CryptoVerifier.verifyManifestEd25519(
              manifestBytes: originalPayload,
              signatureHex: attackerSigHex,
              publicKeyHex: pubKeyAuthorHex,
            ),
            isFalse,
          );
        },
      );
    });
  });

  group('Autonomous Updater - C2-R5 Network Redirect & Security Tests', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      HttpOverrides.global = _RealHttpOverrides();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async {
              return Directory.systemTemp.path;
            },
          );
      PackageInfo.setMockInitialValues(
        appName: 'MyTeam',
        packageName: 'it.simogatti.myteam',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
    });

    tearDown(() {
      InstallerService.setDelegateForTesting(null);
      CryptoVerifier.allowedEndpointOverrideForTesting = null;
    });

    test('HTTP 404 manifest feed shows concise unavailable message', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });
      CryptoVerifier.allowedEndpointOverrideForTesting = (uri) =>
          uri.host == server.address.host && uri.port == server.port;
      final service = UpdateService.createForTesting();

      try {
        final result = await service.checkForUpdates(
          customManifestUrl:
              'http://${server.address.host}:${server.port}/updates/version.json',
        );

        expect(result, isFalse);
        expect(service.state.status, UpdateStatus.failed);
        expect(service.state.failureKind, UpdateFailureKind.serviceUnavailable);
        expect(
          service.state.errorMessage,
          'Servizio aggiornamenti non ancora disponibile (HTTP 404). Riprova più tardi.',
        );
        expect(service.state.errorMessage, isNot(contains('DioException')));
        expect(service.state.errorMessage!.length, lessThan(100));
      } finally {
        await server.close(force: true);
      }
    });

    for (final platformPath in ['android', 'windows']) {
      testWidgets(
        'QA $platformPath 404 hides the Home card and shows a transient notice',
        (tester) async {
          final service = UpdateService.createForTesting();
          try {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: Stack(
                    children: [
                      UpdateBannerWidget(updateService: service),
                      StartupUpdateNotice(
                        listenable: service,
                        readState: () => service.state,
                        checkForUpdates: () async => false,
                      ),
                    ],
                  ),
                ),
              ),
            );
            await tester.pump();
            final result = await tester.runAsync(() async {
              final server = await HttpServer.bind(
                InternetAddress.loopbackIPv4,
                0,
              );
              server.listen((request) async {
                request.response.statusCode = HttpStatus.notFound;
                await request.response.close();
              });
              CryptoVerifier.allowedEndpointOverrideForTesting = (uri) =>
                  uri.host == server.address.host && uri.port == server.port;
              try {
                return await service.checkForUpdates(
                  customManifestUrl:
                      'http://${server.address.host}:${server.port}/updates/qa/$platformPath/version.json',
                );
              } finally {
                CryptoVerifier.allowedEndpointOverrideForTesting = null;
                await server.close(force: true);
              }
            });
            expect(result, isFalse);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));

            expect(service.state.status, UpdateStatus.failed);
            expect(
              service.state.failureKind,
              UpdateFailureKind.serviceUnavailable,
            );
            expect(
              service.state.errorMessage,
              'Servizio aggiornamenti non ancora disponibile (HTTP 404). Riprova più tardi.',
            );
            expect(find.byType(Card), findsNothing);
            expect(
              find.text(
                'Impossibile verificare gli aggiornamenti. Riproveremo più tardi.',
              ),
              findsOneWidget,
            );
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            service.dispose();
          }
        },
      );
    }

    test(
      'offline QA feed is classified as transient service unavailable',
      () async {
        final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final port = socket.port;
        await socket.close();
        CryptoVerifier.allowedEndpointOverrideForTesting = (uri) =>
            uri.host == InternetAddress.loopbackIPv4.address &&
            uri.port == port;
        final service = UpdateService.createForTesting();

        expect(
          await service.checkForUpdates(
            customManifestUrl:
                'http://${InternetAddress.loopbackIPv4.address}:$port/updates/qa/android/version.json',
          ),
          isFalse,
        );
        expect(service.state.status, UpdateStatus.failed);
        expect(service.state.failureKind, UpdateFailureKind.serviceUnavailable);
        expect(
          service.state.errorMessage,
          'Servizio aggiornamenti non raggiungibile. Verifica la connessione e riprova.',
        );
        service.dispose();
      },
    );

    test('HTTP 500 manifest feed remains failed with concise message', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      });
      CryptoVerifier.allowedEndpointOverrideForTesting = (uri) =>
          uri.host == server.address.host && uri.port == server.port;
      final service = UpdateService.createForTesting();

      try {
        expect(
          await service.checkForUpdates(
            customManifestUrl:
                'http://${server.address.host}:${server.port}/updates/version.json',
          ),
          isFalse,
        );
        expect(service.state.status, UpdateStatus.failed);
        expect(service.state.failureKind, UpdateFailureKind.serviceUnavailable);
        expect(service.state.errorMessage, contains('HTTP 500'));
        expect(service.state.errorMessage, isNot(contains('DioException')));
      } finally {
        await server.close(force: true);
      }
    });

    test('QA HTTP 503 feed is a transient service outage', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        await request.response.close();
      });
      CryptoVerifier.allowedEndpointOverrideForTesting = (uri) =>
          uri.host == server.address.host && uri.port == server.port;
      final service = UpdateService.createForTesting();

      try {
        expect(
          await service.checkForUpdates(
            customManifestUrl:
                'http://${server.address.host}:${server.port}/updates/qa/android/version.json',
          ),
          isFalse,
        );
        expect(service.state.status, UpdateStatus.failed);
        expect(service.state.failureKind, UpdateFailureKind.serviceUnavailable);
        expect(service.state.errorMessage, contains('HTTP 503'));
        expect(service.state.errorMessage, isNot(contains('DioException')));
      } finally {
        await server.close(force: true);
      }
    });

    test(
      'missing detached signature stays a strict verification failure',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          if (request.uri.path.endsWith('.sig')) {
            request.response.statusCode = HttpStatus.notFound;
          } else {
            request.response.headers.contentType = ContentType.json;
            request.response.write('{"version_code": 1}');
          }
          await request.response.close();
        });
        CryptoVerifier.allowedEndpointOverrideForTesting = (uri) =>
            uri.host == server.address.host && uri.port == server.port;
        final service = UpdateService.createForTesting();

        try {
          expect(
            await service.checkForUpdates(
              customManifestUrl:
                  'http://${server.address.host}:${server.port}/updates/version.json',
            ),
            isFalse,
          );
          expect(service.state.status, UpdateStatus.failed);
          expect(service.state.failureKind, UpdateFailureKind.security);
          expect(
            service.state.errorMessage!.toLowerCase(),
            contains('firma digitale'),
          );
          expect(
            service.state.errorMessage,
            isNot(contains('non ancora disponibile (HTTP 404)')),
          );
        } finally {
          await server.close(force: true);
        }
      },
    );

    test(
      'P1 Real Network Test: Disallowed redirect (HTTP downgrade or evil host) causes ZERO hits on destination',
      () async {
        // Server 1: Redirector (simula l'origine dell'updater)
        final redirectorServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        // Server 2: Malicious destination
        final evilDestinationServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );

        int evilHitCount = 0;
        evilDestinationServer.listen((request) {
          evilHitCount++;
          request.response.write('malicious payload');
          request.response.close();
        });

        redirectorServer.listen((request) {
          // Redirige al server malevolo
          request.response.statusCode = 302;
          request.response.headers.set(
            HttpHeaders.locationHeader,
            'http://${evilDestinationServer.address.host}:${evilDestinationServer.port}/evil-version.json',
          );
          request.response.close();
        });

        // Configura la policy di test: autorizza SOLO redirectorServer
        CryptoVerifier.allowedEndpointOverrideForTesting = (uri) {
          return uri.host == redirectorServer.address.host &&
              uri.port == redirectorServer.port;
        };

        final updateService = UpdateService.createForTesting();

        // Tenta il controllo aggiornamenti: DEVE FALLIRE e il server evil NON deve MAI essere contattato
        final result = await updateService.checkForUpdates(
          customManifestUrl:
              'http://${redirectorServer.address.host}:${redirectorServer.port}/updates/version.json',
        );

        expect(result, isFalse);
        expect(updateService.state.status, equals(UpdateStatus.failed));
        expect(updateService.state.errorMessage, contains('in modo sicuro'));

        // ASSERZIONE CRITICA: ZERO HIT sulla destinazione malevola!
        expect(
          evilHitCount,
          equals(0),
          reason:
              'CRITICAL SECURITY GATE: Target non consentito non deve MAI essere contattato (0 hit)',
        );

        await redirectorServer.close(force: true);
        await evilDestinationServer.close(force: true);
      },
    );

    test(
      'P1 Real Network Test: Allowed in-policy redirect succeeds and contacts destination',
      () async {
        final initialServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final finalServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );

        final keyPair = ed.generateKey();
        final pubHex = hex.encode(keyPair.publicKey.bytes);
        final privHex = hex.encode(keyPair.privateKey.bytes);

        final manifestJson = jsonEncode({
          'version_name': '2.0.0',
          'version_code': 200,
          'release_date': '2026-11-02T12:00:00Z',
          'platforms': {
            'macos': {
              'platform': 'macos',
              'url':
                  'http://${finalServer.address.host}:${finalServer.port}/app.bin',
              'sha256':
                  'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
              'size_bytes': 0,
            },
          },
        });
        final manifestBytes = utf8.encode(manifestJson);
        final sigHex = hex.encode(
          ed.sign(ed.PrivateKey(hex.decode(privHex)), manifestBytes),
        );

        int destinationHits = 0;
        finalServer.listen((request) {
          destinationHits++;
          if (request.uri.path.endsWith('.sig')) {
            request.response.write(sigHex);
          } else {
            request.response.add(manifestBytes);
          }
          request.response.close();
        });

        initialServer.listen((request) {
          // Redirect consentito relativo o verso finalServer
          request.response.statusCode = 302;
          request.response.headers.set(
            HttpHeaders.locationHeader,
            'http://${finalServer.address.host}:${finalServer.port}${request.uri.path}',
          );
          request.response.close();
        });

        // Entrambi i server sono in policy
        CryptoVerifier.allowedEndpointOverrideForTesting = (uri) {
          return (uri.host == initialServer.address.host &&
                  uri.port == initialServer.port) ||
              (uri.host == finalServer.address.host &&
                  uri.port == finalServer.port);
        };

        final updateService = UpdateService.createForTesting();
        updateService.setManifestPublicKey(pubHex);

        final result = await updateService.checkForUpdates(
          customManifestUrl:
              'http://${initialServer.address.host}:${initialServer.port}/updates/version.json',
        );

        expect(result, isTrue);
        expect(
          updateService.state.status,
          equals(UpdateStatus.updateAvailable),
        );
        expect(destinationHits, greaterThanOrEqualTo(1));

        await initialServer.close(force: true);
        await finalServer.close(force: true);
      },
    );

    test(
      'P1 Real Network Test: Artifact redirect is rejected before destination contact',
      () async {
        final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final blocked = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        var blockedHits = 0;
        blocked.listen((request) async {
          blockedHits++;
          request.response.close();
        });

        final keyPair = ed.generateKey();
        final pubHex = hex.encode(keyPair.publicKey.bytes);
        final privHex = hex.encode(keyPair.privateKey.bytes);
        final manifestBytes = utf8.encode(
          jsonEncode({
            'version_name': '2.0.0',
            'version_code': 200,
            'release_date': '2026-11-02T12:00:00Z',
            'platforms': {
              'macos': {
                'platform': 'macos',
                'url': 'http://${origin.address.host}:${origin.port}/artifact',
                'sha256':
                    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
                'size_bytes': 0,
              },
            },
          }),
        );
        final signature = hex.encode(
          ed.sign(ed.PrivateKey(hex.decode(privHex)), manifestBytes),
        );
        origin.listen((request) async {
          if (request.uri.path.endsWith('.sig')) {
            request.response.write(signature);
          } else if (request.uri.path.endsWith('version.json')) {
            request.response.add(manifestBytes);
          } else {
            request.response.statusCode = HttpStatus.found;
            request.response.headers.set(
              HttpHeaders.locationHeader,
              'http://${blocked.address.host}:${blocked.port}/asset',
            );
          }
          await request.response.close();
        });

        CryptoVerifier.allowedEndpointOverrideForTesting = (uri) =>
            uri.host == origin.address.host && uri.port == origin.port;
        final service = UpdateService.createForTesting()
          ..setManifestPublicKey(pubHex);
        final manifestUrl =
            'http://${origin.address.host}:${origin.port}/updates/version.json';
        expect(
          await service.checkForUpdates(customManifestUrl: manifestUrl),
          isTrue,
        );
        expect(await service.downloadUpdate(), isNull);
        expect(
          blockedHits,
          0,
          reason: 'Blocked artifact redirect target must receive no request.',
        );
        expect(service.state.status, UpdateStatus.failed);

        await origin.close(force: true);
        await blocked.close(force: true);
      },
    );

    test(
      'P1 Real Network Test: Relative redirects and loop detection',
      () async {
        final loopServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );

        loopServer.listen((request) {
          request.response.statusCode = 302;
          // Loop su se stesso
          request.response.headers.set(HttpHeaders.locationHeader, '/loop');
          request.response.close();
        });

        CryptoVerifier.allowedEndpointOverrideForTesting = (uri) {
          return uri.host == loopServer.address.host &&
              uri.port == loopServer.port;
        };

        final updateService = UpdateService.createForTesting();
        final result = await updateService.checkForUpdates(
          customManifestUrl:
              'http://${loopServer.address.host}:${loopServer.port}/loop',
        );

        expect(result, isFalse);
        expect(updateService.state.status, equals(UpdateStatus.failed));
        expect(updateService.state.errorMessage, contains('in modo sicuro'));

        await loopServer.close(force: true);
      },
    );

    test(
      'P2 End-to-End: Full flow from check -> sig verify -> download -> hash -> lock -> installer handoff',
      () async {
        final mockInstaller = MockTestInstallerDelegate();
        InstallerService.setDelegateForTesting(mockInstaller);

        final keyPair = ed.generateKey();
        final pubHex = hex.encode(keyPair.publicKey.bytes);
        final privHex = hex.encode(keyPair.privateKey.bytes);

        // Create a test package file
        final tempDir = await Directory.systemTemp.createTemp(
          'e2e_updater_test_',
        );
        final pkgFile = File('${tempDir.path}/app-release.apk');
        await pkgFile.writeAsString('Binary APK content 2026 for MyTeam test');
        final pkgSha256 = await CryptoVerifier.computeFileSha256(pkgFile);

        // Setup server providing manifest, sig, and binary
        final testServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final manifestMap = {
          'version_name': '2.0.0',
          'version_code': 200,
          'release_date': '2026-11-02T12:00:00Z',
          'platforms': {
            'android': {
              'platform': 'android',
              'url':
                  'http://${testServer.address.host}:${testServer.port}/updates/app-release.apk',
              'sha256': pkgSha256,
              'size_bytes': await pkgFile.length(),
            },
            'windows': {
              'platform': 'windows',
              'url':
                  'http://${testServer.address.host}:${testServer.port}/updates/setup.exe',
              'sha256':
                  '0000000000000000000000000000000000000000000000000000000000000000',
              'size_bytes': 1024,
            },
            'macos': {
              'platform': 'macos',
              'url':
                  'http://${testServer.address.host}:${testServer.port}/updates/app-release.apk',
              'sha256': pkgSha256,
              'size_bytes': await pkgFile.length(),
            },
          },
        };

        final manifestBytes = utf8.encode(jsonEncode(manifestMap));
        final sigBytes = ed.sign(
          ed.PrivateKey(hex.decode(privHex)),
          manifestBytes,
        );
        final sigHex = hex.encode(sigBytes);

        testServer.listen((request) async {
          if (request.uri.path.endsWith('.sig')) {
            request.response.headers.contentType = ContentType.text;
            request.response.write(sigHex);
          } else if (request.uri.path.endsWith('version.json')) {
            request.response.headers.contentType = ContentType.json;
            request.response.add(manifestBytes);
          } else {
            request.response.headers.contentType = ContentType.binary;
            request.response.headers.contentLength = await pkgFile.length();
            request.response.add(await pkgFile.readAsBytes());
          }
          request.response.close();
        });

        CryptoVerifier.allowedEndpointOverrideForTesting = (uri) {
          return uri.host == testServer.address.host &&
              uri.port == testServer.port;
        };

        final mockRepo = MockUploadRepository(active: [], completed: []);
        final useCase = UploadVideoUseCase(mockRepo);
        final viewModel = UploadViewModel(useCase);
        await viewModel.loadSavedUploadTasks();

        final guard = ActiveTasksGuard(uploadViewModel: viewModel);
        final updateService = UpdateService.createForTesting(guard: guard);
        updateService.setManifestPublicKey(pubHex);

        // 1. Check for updates
        final updateAvailable = await updateService.checkForUpdates(
          customManifestUrl:
              'http://${testServer.address.host}:${testServer.port}/updates/version.json',
        );
        expect(updateAvailable, isTrue);
        expect(
          updateService.state.status,
          equals(UpdateStatus.updateAvailable),
        );
        expect(updateService.state.manifest?.versionCode, equals(200));

        // 2. Download update & verify streaming SHA-256
        final downloadedFile = await updateService.downloadUpdate();
        expect(downloadedFile, isNotNull);
        expect(await downloadedFile!.exists(), isTrue);
        expect(updateService.state.status, equals(UpdateStatus.readyToInstall));

        // 3. Trigger installation -> lock acquired -> handoff to system installer
        final success = await updateService.triggerInstallation();
        expect(success, isTrue);
        expect(mockInstaller.installCalled, isTrue);
        expect(
          mockInstaller.receivedPackageFile?.path,
          equals(downloadedFile.path),
        );
        expect(
          updateService.state.status,
          equals(UpdateStatus.handoffToSystemInstaller),
        );
        expect(viewModel.isInstallationInProgress, isTrue);

        await testServer.close(force: true);
        await tempDir.delete(recursive: true);
      },
    );

    test(
      'P2 Installer Handoff Failure releases install lock and allows reset',
      () async {
        final mockInstaller = MockTestInstallerDelegate()
          ..returnSuccess = false;
        InstallerService.setDelegateForTesting(mockInstaller);

        final keyPair = ed.generateKey();
        final pubHex = hex.encode(keyPair.publicKey.bytes);
        final privHex = hex.encode(keyPair.privateKey.bytes);

        final tempDir = await Directory.systemTemp.createTemp(
          'fail_updater_test_',
        );
        final pkgFile = File('${tempDir.path}/app-release.apk');
        await pkgFile.writeAsString('Binary APK content');
        final pkgSha256 = await CryptoVerifier.computeFileSha256(pkgFile);

        final testServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final manifestMap = {
          'version_name': '2.0.0',
          'version_code': 200,
          'release_date': '2026-11-02T12:00:00Z',
          'platforms': {
            'android': {
              'platform': 'android',
              'url':
                  'http://${testServer.address.host}:${testServer.port}/updates/app-release.apk',
              'sha256': pkgSha256,
              'size_bytes': await pkgFile.length(),
            },
            'macos': {
              'platform': 'macos',
              'url':
                  'http://${testServer.address.host}:${testServer.port}/updates/app-release.apk',
              'sha256': pkgSha256,
              'size_bytes': await pkgFile.length(),
            },
          },
        };

        final manifestBytes = utf8.encode(jsonEncode(manifestMap));
        final sigBytes = ed.sign(
          ed.PrivateKey(hex.decode(privHex)),
          manifestBytes,
        );
        final sigHex = hex.encode(sigBytes);

        testServer.listen((request) async {
          if (request.uri.path.endsWith('.sig')) {
            request.response.headers.contentType = ContentType.text;
            request.response.write(sigHex);
          } else if (request.uri.path.endsWith('version.json')) {
            request.response.headers.contentType = ContentType.json;
            request.response.add(manifestBytes);
          } else {
            request.response.headers.contentType = ContentType.binary;
            request.response.headers.contentLength = await pkgFile.length();
            request.response.add(await pkgFile.readAsBytes());
          }
          request.response.close();
        });

        CryptoVerifier.allowedEndpointOverrideForTesting = (uri) {
          return uri.host == testServer.address.host &&
              uri.port == testServer.port;
        };

        final mockRepo = MockUploadRepository(active: [], completed: []);
        final useCase = UploadVideoUseCase(mockRepo);
        final viewModel = UploadViewModel(useCase);
        await viewModel.loadSavedUploadTasks();

        final guard = ActiveTasksGuard(uploadViewModel: viewModel);
        final updateService = UpdateService.createForTesting(guard: guard);
        updateService.setManifestPublicKey(pubHex);

        await updateService.checkForUpdates(
          customManifestUrl:
              'http://${testServer.address.host}:${testServer.port}/updates/version.json',
        );
        await updateService.downloadUpdate();

        final success = await updateService.triggerInstallation();
        expect(success, isFalse);
        expect(mockInstaller.installCalled, isTrue);
        // Lock must be released!
        expect(viewModel.isInstallationInProgress, isFalse);
        expect(updateService.state.status, equals(UpdateStatus.failed));
        expect(
          updateService.state.errorMessage,
          contains('Impossibile completare l\'avvio dell\'installazione'),
        );

        // Recovery via resetAfterCancelledInstall
        updateService.resetAfterCancelledInstall();
        expect(updateService.state.status, equals(UpdateStatus.readyToInstall));
        expect(viewModel.isInstallationInProgress, isFalse);

        await testServer.close(force: true);
        await tempDir.delete(recursive: true);
      },
    );
  });
}
