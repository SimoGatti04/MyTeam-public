import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../services/debug_logger.dart';
import 'models/update_manifest.dart';
import 'models/update_state.dart';
import 'crypto_verifier.dart';
import 'updater_channel_config.dart';
import 'active_tasks_guard.dart';
import 'installer_service.dart';

class SecurityException implements Exception {
  final String message;
  const SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}

/// Servizio centrale dell'updater autonomo di MyTeam.
///
/// Sicurezza dei Redirect (P1 - C2-R5):
/// - TUTTE le richieste HTTP dell'updater sono eseguite con followRedirects = false.
/// - Ogni singolo redirect HTTP (301, 302, 303, 307, 308) viene intercettato e validato
///   esplicitamente PRIMA di stabilire qualsiasi connessione verso la nuova destinazione.
/// - La nuova destinazione viene validata tramite CryptoVerifier.isAllowedEndpointUrl:
///   obbligo assoluto di HTTPS, host consentito, nessun downgrade a HTTP, nessun loop,
///   nessun host esterno o con credenziali incorporate.
/// - Il numero massimo di salti di redirect è tassativamente limitato a 5.
class UpdateService extends ChangeNotifier {
  static const int maxRedirectHops = 5;
  static final RegExp _qaManifestPath = RegExp(
    r'^/updates/qa/(?:android|windows)/version\.json$',
  );
  static UpdateService? _instance;

  static UpdateService get instance {
    _instance ??= UpdateService._();
    return _instance!;
  }

  final Dio _dio;
  ActiveTasksGuard _guard;
  final UpdaterChannelConfig _channelConfig;

  // Chiave pubblica Ed25519 per la validazione della firma asimmetrica del manifest.
  // La chiave privata resta in un ambiente di firma autorizzato, mai nel client o nel repository.
  late String _manifestPublicKeyHex;

  UpdateState _state = const UpdateState();
  CancelToken? _cancelToken;

  @visibleForTesting
  factory UpdateService.createForTesting({
    Dio? dio,
    ActiveTasksGuard? guard,
    UpdaterChannelConfig? channelConfig,
  }) {
    return UpdateService._(
      dio: dio,
      guard: guard,
      channelConfig: channelConfig,
    );
  }

  UpdateService._({
    Dio? dio,
    ActiveTasksGuard? guard,
    UpdaterChannelConfig? channelConfig,
  }) : _dio = dio ?? _createDefaultDio(),
       _guard = guard ?? ActiveTasksGuard(),
       _channelConfig =
           channelConfig ?? UpdaterChannelConfig.fromBuildDefines() {
    _manifestPublicKeyHex = _channelConfig.publicKeyHex;
  }

  static Dio _createDefaultDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(minutes: 5),
      ),
    );
  }

  /// Consente l'iniezione della guardia con ViewModel reale (o mock per test)
  void setGuard(ActiveTasksGuard guard) {
    _guard = guard;
    notifyListeners();
  }

  /// Consente di impostare la chiave pubblica Ed25519 per la verifica del manifest (es. nei test)
  void setManifestPublicKey(String keyHex) {
    if (kReleaseMode || _channelConfig.isQa) {
      throw StateError(
        'This build uses its compile-time pinned manifest verification key.',
      );
    }
    _manifestPublicKeyHex = keyHex.trim();
  }

  UpdateState get state => _state;
  ActiveTasksGuard get guard => _guard;

  @visibleForTesting
  String get manifestPublicKeyHexForTesting => _manifestPublicKeyHex;

  /// URL predefinito del manifest di aggiornamento
  String get manifestUrl => _channelConfig.manifestUrl;
  bool get isQaChannel => _channelConfig.isQa;

  void _updateState(UpdateState newState) {
    _state = newState;
    notifyListeners();
  }

  bool _isManifestRequest(Uri uri) =>
      uri.path == '/updates/version.json' || _qaManifestPath.hasMatch(uri.path);

  String _friendlyCheckError(Object error) {
    if (_channelConfig.isQa && !_channelConfig.isValid) {
      return 'Configurazione del canale QA non valida. Aggiornamenti disabilitati.';
    }
    if (error is DioException) {
      final status = error.response?.statusCode;
      final isManifestRequest = _isManifestRequest(error.requestOptions.uri);
      if (isManifestRequest && status == HttpStatus.notFound) {
        return 'Servizio aggiornamenti non ancora disponibile (HTTP 404). Riprova più tardi.';
      }
      if (isManifestRequest && status != null && status >= 500) {
        return 'Servizio aggiornamenti temporaneamente non disponibile (HTTP $status). Riprova più tardi.';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'Controllo aggiornamenti scaduto. Verifica la connessione e riprova.';
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.unknown) {
        return 'Servizio aggiornamenti non raggiungibile. Verifica la connessione e riprova.';
      }
      return 'Impossibile verificare gli aggiornamenti in modo sicuro. Riprova più tardi.';
    }

    if (error is FormatException &&
        error.message.contains('firma digitale Ed25519 detached assente')) {
      return 'Firma digitale dell’aggiornamento assente. Aggiornamento rifiutato.';
    }
    if (error is FormatException &&
        error.message.contains('firma digitale Ed25519 non valida')) {
      return 'Firma digitale dell’aggiornamento non valida. Aggiornamento rifiutato.';
    }
    return 'Impossibile verificare gli aggiornamenti in modo sicuro. Riprova più tardi.';
  }

  UpdateFailureKind _failureKindFor(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final isManifestRequest = _isManifestRequest(error.requestOptions.uri);
      if ((isManifestRequest &&
              (status == HttpStatus.notFound ||
                  status == HttpStatus.tooManyRequests ||
                  (status != null && status >= 500))) ||
          (status == null &&
              (error.type == DioExceptionType.connectionError ||
                  error.type == DioExceptionType.connectionTimeout ||
                  error.type == DioExceptionType.receiveTimeout ||
                  error.type == DioExceptionType.sendTimeout ||
                  error.type == DioExceptionType.unknown))) {
        return UpdateFailureKind.serviceUnavailable;
      }
      return UpdateFailureKind.operation;
    }
    if (error is SecurityException || error is FormatException) {
      return UpdateFailureKind.security;
    }
    return UpdateFailureKind.operation;
  }

  UpdateFailureKind _downloadFailureKindFor(Object error) {
    if (error is SecurityException || error is FormatException) {
      return UpdateFailureKind.security;
    }
    return UpdateFailureKind.operation;
  }

  String _friendlyDownloadError(Object error) {
    if (error is DioException &&
        (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout)) {
      return 'Download aggiornamento scaduto. Verifica la connessione e riprova.';
    }
    if (error is DioException) {
      return 'Download aggiornamento non riuscito. Controlla la connessione e riprova.';
    }
    if (error is FormatException || error is SecurityException) {
      return 'Verifica di sicurezza non superata. Pacchetto rifiutato.';
    }
    return 'Download aggiornamento non riuscito. Riprova più tardi.';
  }

  String _safeUpdateDiagnostic(Object error) {
    if (error is DioException) {
      final uri = error.requestOptions.uri;
      final safeUri = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: uri.path,
      );
      return 'DioException type=${error.type.name}, '
          'status=${error.response?.statusCode ?? 'none'}, uri=$safeUri';
    }
    return error.runtimeType.toString();
  }

  /// Risolve l'URI di redirect gestendo sia percorsi relativi che assoluti
  static Uri resolveRedirectUri(Uri currentUri, String location) {
    final trimmedLocation = location.trim();
    if (trimmedLocation.isEmpty) {
      throw const SecurityException(
        'Header Location del redirect vuoto o mancante.',
      );
    }
    final parsed = Uri.parse(trimmedLocation);
    if (parsed.hasScheme) {
      return parsed;
    }
    return currentUri.resolve(trimmedLocation);
  }

  /// Esegue una richiesta HTTP GET seguendo manualmente i redirect con validazione preventiva (P1)
  Future<Response<T>> _getWithManualRedirects<T>(
    String initialUrl, {
    ResponseType responseType = ResponseType.json,
    CancelToken? cancelToken,
  }) async {
    Uri currentUri = Uri.parse(initialUrl);
    final visitedUris = <String>{};

    for (int hop = 0; hop <= maxRedirectHops; hop++) {
      if (!CryptoVerifier.isAllowedEndpointUrl(currentUri)) {
        throw SecurityException(
          'Destinazione non autorizzata dalla policy di sicurezza: $currentUri (hop $hop)',
        );
      }

      final uriString = currentUri.toString();
      if (visitedUris.contains(uriString)) {
        throw SecurityException(
          'Rilevato loop di redirect infinito per URI: $currentUri',
        );
      }
      visitedUris.add(uriString);

      final response = await _dio.get<T>(
        uriString,
        cancelToken: cancelToken,
        options: Options(
          responseType: responseType,
          followRedirects: false,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 400,
        ),
      );

      final statusCode = response.statusCode ?? 200;
      if (statusCode >= 300 && statusCode < 400) {
        if (hop == maxRedirectHops) {
          throw const SecurityException(
            'Superato il limite massimo di redirect consentiti (5).',
          );
        }
        final locationHeader = response.headers.value(
          HttpHeaders.locationHeader,
        );
        if (locationHeader == null || locationHeader.trim().isEmpty) {
          throw SecurityException(
            'Risposta HTTP $statusCode senza header Location valido da $currentUri',
          );
        }

        // Risolvi il target ed esegui la validazione preventiva PRIMA di stabilire qualsiasi connessione
        final targetUri = resolveRedirectUri(currentUri, locationHeader);
        if (!CryptoVerifier.isAllowedEndpointUrl(targetUri)) {
          throw SecurityException(
            'Redirect vietato verso destinazione o schema non sicuro: $targetUri (da $currentUri)',
          );
        }

        currentUri = targetUri;
        continue;
      }

      return response;
    }

    throw const SecurityException(
      'Superato il limite massimo di redirect consentiti (5).',
    );
  }

  /// Verifica la disponibilità di aggiornamenti interrogando version.json su HTTPS
  /// con firma Ed25519 detached obbligatoria sul payload grezzo del manifest.
  Future<bool> checkForUpdates({
    String? customManifestUrl,
    bool skipSignatureVerification = false,
  }) async {
    // Non avviare un nuovo controllo se stiamo già scaricando o installando
    if (_state.status == UpdateStatus.downloading ||
        _state.status == UpdateStatus.verifying ||
        _state.status == UpdateStatus.installing) {
      DebugLogger.info(
        'UpdateService: download o installazione in corso, salto controllo',
      );
      return false;
    }

    _updateState(
      _state.copyWith(status: UpdateStatus.checking, clearFailure: true),
    );

    try {
      if (!_channelConfig.isValid) {
        throw SecurityException(_channelConfig.configurationError!);
      }
      if (_channelConfig.isQa &&
          customManifestUrl != null &&
          customManifestUrl != manifestUrl) {
        throw const SecurityException(
          'QA updater feed URL is fixed by the build channel.',
        );
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 1;
      final currentVersionName = packageInfo.version;

      DebugLogger.info(
        'UpdateService: Versione client attuale: $currentVersionName+$currentVersionCode',
      );

      final targetUrl = _channelConfig.isQa
          ? manifestUrl
          : customManifestUrl ?? manifestUrl;

      // SICUREZZA RIGOROSA ENDPOINT: Controllo schema ed eccezione localhost
      final uri = Uri.parse(targetUrl);
      if (!CryptoVerifier.isAllowedEndpointUrl(uri)) {
        throw const FormatException(
          "L'URL del manifest di aggiornamento non rispetta i vincoli di sicurezza (richiesto HTTPS).",
        );
      }

      // Scarica i byte grezzi del manifest con validazione manuale preventiva di ogni redirect (P1)
      final response = await _getWithManualRedirects<List<int>>(
        targetUrl,
        responseType: ResponseType.bytes,
      );

      final rawBytes = response.data;
      if (rawBytes == null || rawBytes.isEmpty) {
        throw const FormatException(
          'Risposta manifest vuota o nulla dal server.',
        );
      }

      final rawBody = utf8.decode(rawBytes);
      final Map<String, dynamic> jsonData =
          jsonDecode(rawBody) as Map<String, dynamic>;

      // Canonical format: detached version.json.sig over the exact raw manifest bytes.
      String? effectiveSignature;
      if (!skipSignatureVerification || _channelConfig.isQa || kReleaseMode) {
        try {
          final sigResponse = await _getWithManualRedirects<List<int>>(
            '$targetUrl.sig',
            responseType: ResponseType.bytes,
          );
          if (sigResponse.data != null && sigResponse.data!.isNotEmpty) {
            effectiveSignature = utf8.decode(sigResponse.data!).trim();
          }
        } catch (e) {
          DebugLogger.debug(
            'UpdateService: Detached .sig unavailable: ${_safeUpdateDiagnostic(e)}',
          );
        }
      }

      // In release mode, skipSignatureVerification è tassativamente proibito
      final bool mustVerifySignature =
          kReleaseMode || _channelConfig.isQa || !skipSignatureVerification;

      if (mustVerifySignature) {
        if (effectiveSignature == null || effectiveSignature.trim().isEmpty) {
          throw const FormatException(
            'Autenticazione manifest fallita: firma digitale Ed25519 detached assente (.sig).',
          );
        }

        // Verifica crittografica sui byte grezzi esatti senza riserializzazione JSON
        final isValidSignature = CryptoVerifier.verifyManifestEd25519(
          manifestBytes: rawBytes,
          signatureHex: effectiveSignature,
          publicKeyHex: _manifestPublicKeyHex,
        );

        if (!isValidSignature) {
          throw const FormatException(
            'Autenticazione manifest fallita: firma digitale Ed25519 non valida o manifest manomesso.',
          );
        }

        DebugLogger.info(
          'UpdateService: Manifest autenticato con successo tramite firma digitale Ed25519 detached.',
        );
      } else {
        DebugLogger.warning(
          'UpdateService: ATTENZIONE: Verifica firma manifest bypassata per test/sviluppo.',
        );
      }

      final manifest = UpdateManifest.fromJson(
        jsonData,
        detachedSignature: effectiveSignature,
      );

      // Risolvi l'artefatto specifico per la piattaforma in esecuzione
      String platformKey;
      if (Platform.isAndroid) {
        platformKey = 'android';
      } else if (Platform.isWindows) {
        platformKey = 'windows';
      } else if (Platform.isMacOS) {
        platformKey = 'macos';
      } else {
        platformKey = 'unknown';
      }

      final artifact = manifest.getArtifactForPlatform(platformKey);

      // Logica di confronto versioni: verifica versionCode
      if (manifest.versionCode > currentVersionCode) {
        if (artifact == null) {
          throw FormatException(
            'Nessun pacchetto di aggiornamento disponibile per la piattaforma $platformKey',
          );
        }

        DebugLogger.info(
          'UpdateService: Nuovo aggiornamento trovato: v${manifest.versionName} (${manifest.versionCode})',
        );
        _updateState(
          _state.copyWith(
            status: UpdateStatus.updateAvailable,
            manifest: manifest,
            artifact: artifact,
            clearFailure: true,
          ),
        );
        return true;
      } else {
        DebugLogger.info(
          'UpdateService: Il client è già aggiornato all\'ultima versione.',
        );
        _updateState(
          _state.copyWith(
            status: UpdateStatus.upToDate,
            manifest: manifest,
            artifact: artifact,
            clearFailure: true,
          ),
        );
        return false;
      }
    } catch (e) {
      DebugLogger.error(
        'UpdateService errore verifica aggiornamenti: ${_safeUpdateDiagnostic(e)}',
      );
      _updateState(
        _state.copyWith(
          status: UpdateStatus.failed,
          failureKind: _failureKindFor(e),
          errorMessage: _friendlyCheckError(e),
        ),
      );
      return false;
    }
  }

  /// Scarica l'artefatto con verifica progressiva e validazione SHA-256.
  /// Implementa gestione esplicita dei redirect con pre-validazione ad ogni hop (P1).
  Future<File?> downloadUpdate() async {
    final artifact = _state.artifact;
    if (artifact == null) {
      _updateState(
        _state.copyWith(
          status: UpdateStatus.failed,
          failureKind: UpdateFailureKind.operation,
          errorMessage: 'Nessun artefatto selezionato per il download.',
        ),
      );
      return null;
    }

    _cancelToken = CancelToken();

    _updateState(
      _state.copyWith(
        status: UpdateStatus.downloading,
        clearFailure: true,
        progress: 0.0,
        downloadedBytes: 0,
        totalBytes: artifact.sizeBytes,
        errorMessage: null,
      ),
    );

    File? targetFile;

    try {
      final tempDir = await getTemporaryDirectory();
      final updatesDir = Directory('${tempDir.path}/myteam_updates');
      if (!await updatesDir.exists()) {
        await updatesDir.create(recursive: true);
      }

      final uri = Uri.parse(artifact.url);
      final filename = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : 'update_${_state.manifest?.versionCode ?? 0}';
      final savePath = '${updatesDir.path}/$filename';
      targetFile = File(savePath);

      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      DebugLogger.info(
        'UpdateService: Download di ${artifact.url} in $savePath',
      );

      // Validazione iniziale dell'URL dell'artefatto
      if (!CryptoVerifier.isAllowedArtifactUrl(artifact.url)) {
        throw SecurityException(
          'URL artefatto non consentito: ${artifact.url}',
        );
      }

      // Connessione in streaming con gestione manuale preventiva dei redirect (P1)
      Uri currentUri = uri;
      final visitedUris = <String>{};
      Response<ResponseBody>? streamResponse;

      for (int hop = 0; hop <= maxRedirectHops; hop++) {
        if (!CryptoVerifier.isAllowedEndpointUrl(currentUri)) {
          throw SecurityException(
            'Download artefatto bloccato verso destinazione o schema non sicuro: $currentUri (hop $hop)',
          );
        }

        final uriString = currentUri.toString();
        if (visitedUris.contains(uriString)) {
          throw SecurityException(
            'Rilevato loop di redirect infinito per download: $currentUri',
          );
        }
        visitedUris.add(uriString);

        final response = await _dio.get<ResponseBody>(
          uriString,
          cancelToken: _cancelToken,
          options: Options(
            responseType: ResponseType.stream,
            followRedirects: false,
            validateStatus: (status) =>
                status != null && status >= 200 && status < 400,
          ),
        );

        final statusCode = response.statusCode ?? 200;
        if (statusCode >= 300 && statusCode < 400) {
          if (hop == maxRedirectHops) {
            throw const SecurityException(
              'Superato il limite massimo di redirect consentiti (5) per il download.',
            );
          }
          final locationHeader = response.headers.value(
            HttpHeaders.locationHeader,
          );
          if (locationHeader == null || locationHeader.trim().isEmpty) {
            throw SecurityException(
              'Risposta HTTP $statusCode senza header Location valido da $currentUri',
            );
          }

          final targetUri = resolveRedirectUri(currentUri, locationHeader);
          final redirectBody = response.data?.stream;
          if (!CryptoVerifier.isAllowedEndpointUrl(targetUri)) {
            await redirectBody?.listen((_) {}).cancel();
            throw SecurityException(
              'Download redirect vietato verso destinazione o schema non sicuro: $targetUri (da $currentUri)',
            );
          }
          await redirectBody?.listen((_) {}).cancel();

          currentUri = targetUri;
          continue;
        }

        streamResponse = response;
        break;
      }

      if (streamResponse == null || streamResponse.data == null) {
        throw const FormatException('Risposta di download vuota o non valida.');
      }

      // Stream dei byte nel file locale con aggiornamento del progresso
      final fileSink = targetFile.openWrite();
      int receivedBytes = 0;
      final contentLengthHeader = streamResponse.headers.value(
        HttpHeaders.contentLengthHeader,
      );
      final totalExpectedBytes =
          int.tryParse(contentLengthHeader ?? '') ?? artifact.sizeBytes;

      try {
        await for (final chunk in streamResponse.data!.stream) {
          if (_cancelToken?.isCancelled ?? false) {
            throw DioException(
              requestOptions: streamResponse.requestOptions,
              error: 'Download annullato dall\'utente',
              type: DioExceptionType.cancel,
            );
          }
          fileSink.add(chunk);
          receivedBytes += chunk.length;
          final double progress = totalExpectedBytes > 0
              ? receivedBytes / totalExpectedBytes
              : 0.0;
          _updateState(
            _state.copyWith(
              progress: progress.clamp(0.0, 1.0),
              downloadedBytes: receivedBytes,
              totalBytes: totalExpectedBytes > 0
                  ? totalExpectedBytes
                  : artifact.sizeBytes,
            ),
          );
        }
      } finally {
        await fileSink.flush();
        await fileSink.close();
      }

      // Fase di verifica integrità crittografica SHA-256
      _updateState(_state.copyWith(status: UpdateStatus.verifying));
      DebugLogger.info(
        'UpdateService: Verifica integrità SHA-256 per $savePath',
      );

      final bool isValid = await CryptoVerifier.verifySha256(
        targetFile,
        artifact.sha256,
      );
      if (!isValid) {
        await targetFile.delete();
        throw const FormatException(
          'Verifica integrità fallita: SHA-256 non corrispondente. Pacchetto eliminato per sicurezza.',
        );
      }

      DebugLogger.info('UpdateService: SHA-256 verificato con successo.');

      _updateState(
        _state.copyWith(
          status: UpdateStatus.readyToInstall,
          downloadedFilePath: savePath,
        ),
      );

      return targetFile;
    } catch (e) {
      if (targetFile != null && await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (_) {}
      }
      if (e is DioException && CancelToken.isCancel(e)) {
        DebugLogger.info('UpdateService: Download annullato dall\'utente');
        _updateState(_state.copyWith(status: UpdateStatus.idle));
      } else {
        DebugLogger.error(
          'UpdateService errore download: ${_safeUpdateDiagnostic(e)}',
        );
        _updateState(
          _state.copyWith(
            status: UpdateStatus.failed,
            failureKind: _downloadFailureKindFor(e),
            errorMessage: _friendlyDownloadError(e),
          ),
        );
      }
      return null;
    } finally {
      _cancelToken = null;
    }
  }

  /// Annulla un download in corso
  void cancelDownload() {
    _cancelToken?.cancel('Operazione annullata dall\'utente');
    _cancelToken = null;
  }

  /// Avvia l\'installazione solo se la guardia sui task attivi lo consente.
  /// Protegge atomicamente l'app impedendo che nuove operazioni vengano avviate prima del passaggio
  /// di consegne all'installer di sistema.
  Future<bool> triggerInstallation() async {
    final filePath = _state.downloadedFilePath;
    if (filePath == null) {
      _updateState(
        _state.copyWith(
          status: UpdateStatus.failed,
          failureKind: UpdateFailureKind.operation,
          errorMessage: 'Nessun file scaricato pronto per l\'installazione.',
        ),
      );
      return false;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      _updateState(
        _state.copyWith(
          status: UpdateStatus.failed,
          failureKind: UpdateFailureKind.operation,
          errorMessage: 'File di aggiornamento non trovato sul disco.',
        ),
      );
      return false;
    }

    // Acquisizione atomica del lock di installazione (coordinata senza finestre di concorrenza)
    final lockAcquired = _guard.acquireInstallationLock();
    if (!lockAcquired) {
      final desc = _guard.activeOperationsDescription;
      DebugLogger.warning(
        'UpdateService: Installazione bloccata da task attivi o mancata acquisizione lock: $desc',
      );
      _updateState(
        _state.copyWith(
          status: UpdateStatus.blockedByActiveTasks,
          activeTasksDescription: desc,
        ),
      );
      return false;
    }

    _updateState(_state.copyWith(status: UpdateStatus.installing));

    bool launched = false;
    try {
      launched = await InstallerService.installPackage(packageFile: file);
    } catch (e) {
      DebugLogger.error(
        'UpdateService: Errore durante invocazione InstallerService: $e',
      );
      launched = false;
    }

    if (!launched) {
      // In caso di errore prima o durante l\'avvio dell'installer, rilascia il lock per consentire il recupero
      _guard.releaseInstallationLock();
      _updateState(
        _state.copyWith(
          status: UpdateStatus.failed,
          failureKind: UpdateFailureKind.operation,
          errorMessage: 'Impossibile completare l\'avvio dell\'installazione.',
        ),
      );
      return false;
    }

    // Passaggio di consegne completato all'installer di sistema OS (distinto da installazione completata)
    _updateState(
      _state.copyWith(status: UpdateStatus.handoffToSystemInstaller),
    );
    return true;
  }

  /// Consente il recupero controllato dello stato e il rilascio del lock qualora l\'utente
  /// torni all\'applicazione dopo aver annullato o completato l\'installazione di sistema.
  void resetAfterCancelledInstall() {
    _guard.releaseInstallationLock();
    if (_state.downloadedFilePath != null) {
      _updateState(_state.copyWith(status: UpdateStatus.readyToInstall));
    } else {
      _updateState(_state.copyWith(status: UpdateStatus.idle));
    }
  }
}
