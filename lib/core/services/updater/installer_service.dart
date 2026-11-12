import 'dart:io';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import '../debug_logger.dart';

/// Servizio per invocare l'installazione su Android e Windows
/// Delegate per astrarre l'esecuzione dell'installazione nativa (utilizzabile per test/mock)
abstract class InstallerDelegate {
  Future<bool> installPackage({
    required File packageFile,
    List<String>? requestedArgs,
  });
}

class DefaultInstallerDelegate implements InstallerDelegate {
  const DefaultInstallerDelegate();

  @override
  Future<bool> installPackage({
    required File packageFile,
    List<String>? requestedArgs,
  }) async {
    if (Platform.isAndroid) {
      return await InstallerService.installAndroidApkDirect(packageFile);
    } else if (Platform.isWindows) {
      return await InstallerService.installWindowsExeDirect(packageFile, requestedArgs);
    } else {
      DebugLogger.error('InstallerService: Platform not supported for automatic install: ${Platform.operatingSystem}');
      return false;
    }
  }
}

/// Servizio per invocare l'installazione su Android e Windows
class InstallerService {
  static const MethodChannel _androidChannel = MethodChannel('it.simogatti.myteam/updater');
  static InstallerDelegate _delegate = const DefaultInstallerDelegate();

  /// Consente di iniettare un delegate personalizzato (es. nei test unitari ed e2e)
  static void setDelegateForTesting(InstallerDelegate? delegate) {
    _delegate = delegate ?? const DefaultInstallerDelegate();
  }

  // Whitelist dei soli argomenti consentiti per l'installer Inno Setup su Windows
  static const List<String> _allowedWindowsArgs = [
    '/SILENT',
    '/VERYSILENT',
    '/CLOSEAPPLICATIONS',
    '/NOFORCECLOSEAPPLICATIONS',
    '/NORESTARTAPPLICATIONS',
    '/NORESTART',
    '/SUPPRESSMSGBOXES',
  ];

  /// Avvia l'installazione del pacchetto scaricato e verificato
  static Future<bool> installPackage({
    required File packageFile,
    List<String>? requestedArgs,
  }) async {
    if (!await packageFile.exists()) {
      DebugLogger.error('InstallerService: Package file does not exist: ${packageFile.path}');
      return false;
    }

    return await _delegate.installPackage(
      packageFile: packageFile,
      requestedArgs: requestedArgs,
    );
  }

  /// Android: invoca il MethodChannel installApk su MainActivity.kt
  static Future<bool> installAndroidApkDirect(File apkFile) async {
    try {
      DebugLogger.info('InstallerService: Launching Android package installer for ${apkFile.path}');
      final bool? result = await _androidChannel.invokeMethod<bool>('installApk', {
        'filePath': apkFile.path,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      DebugLogger.error('InstallerService Android error: ${e.message} (${e.code})');
      return false;
    } catch (e) {
      DebugLogger.error('InstallerService Android unexpected error: $e');
      return false;
    }
  }

  /// Builds safe defaults and enforces graceful Restart Manager shutdown
  /// without relaunch.
  @visibleForTesting
  static List<String> windowsInstallerArgsForTesting(
    List<String>? requestedArgs,
  ) =>
      _windowsInstallerArgs(requestedArgs);

  static List<String> _windowsInstallerArgs(List<String>? requestedArgs) {
    final safeArgs = <String>[];
    for (final arg in requestedArgs ?? const <String>[]) {
      final upper = arg.trim().toUpperCase();
      if (_allowedWindowsArgs.contains(upper)) {
        safeArgs.add(upper);
      } else {
        DebugLogger.warning(
          'InstallerService Windows: Rifiutato argomento non consentito: $arg',
        );
      }
    }
    if (!safeArgs.contains('/SILENT') && !safeArgs.contains('/VERYSILENT')) {
      safeArgs.add('/SILENT');
    }
    // Restart Manager closes the app normally before replacing loaded DLLs.
    safeArgs.addAll([
      '/CLOSEAPPLICATIONS',
      '/NOFORCECLOSEAPPLICATIONS',
      '/NORESTARTAPPLICATIONS',
      '/NORESTART',
    ]);
    return safeArgs.toSet().toList();
  }

  /// Windows: esegue l'installer Inno Setup in modalità utente
  /// SICUREZZA: Solo argomenti pre-approvati in whitelist; rifiuto di qualsiasi argomento arbitrario
  static Future<bool> installWindowsExeDirect(File exeFile, List<String>? requestedArgs) async {
    try {
      final safeArgs = _windowsInstallerArgs(requestedArgs);

      DebugLogger.info('InstallerService: Launching Windows installer: ${exeFile.path} with sanitized args: $safeArgs');

      final process = await Process.start(
        exeFile.path,
        safeArgs,
        mode: ProcessStartMode.detached,
      );

      DebugLogger.info('InstallerService: Windows installer detached with PID ${process.pid}');
      return true;
    } catch (e) {
      DebugLogger.error('InstallerService Windows execution error: $e');
      return false;
    }
  }
}
