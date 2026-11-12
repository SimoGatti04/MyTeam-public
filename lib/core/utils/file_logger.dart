import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// File logger per app Windows release
/// Permette di vedere i log anche quando l'app è eseguita come .exe
/// 
/// NOTA: Attualmente DISATTIVATO. Per riattivare, imposta _enabled = true
class FileLogger {
  static File? _logFile;
  static bool _initialized = false;
  
  // Flag per abilitare/disabilitare file logging
  static const bool _enabled = false; // DISATTIVATO per ora
  
  /// Inizializza file logger (solo su Windows in release)
  static Future<void> initialize() async {
    if (!_enabled || !Platform.isWindows || kDebugMode) {
      // Disabilitato o non Windows o debug mode
      return;
    }
    
    try {
      // Ottieni directory documenti utente
      final appDir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${appDir.path}/MyTeam');
      
      // Crea directory se non esiste
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      
      // Crea file log con timestamp
      final timestamp = DateTime.now().toString().replaceAll(':', '-').split('.')[0];
      _logFile = File('${logDir.path}/myteam_log_$timestamp.txt');
      
      // Scrivi header
      await _logFile!.writeAsString(
        '=== MyTeam Video App Log ===\n'
        'Started: ${DateTime.now()}\n'
        'Platform: Windows\n'
        '================================\n\n',
        mode: FileMode.write,
      );
      
      _initialized = true;
      
      if (kDebugMode) {
        debugPrint('✅ [FileLogger] Inizializzato: ${_logFile!.path}');
      }
    } catch (e) {
      // Ignora errori di inizializzazione
      if (kDebugMode) {
        debugPrint('⚠️ [FileLogger] Errore inizializzazione: $e');
      }
    }
  }
  
  /// Log messaggio su file
  static Future<void> log(String message, {String? level}) async {
    if (!_enabled || !_initialized || _logFile == null) {
      return;
    }
    
    try {
      final timestamp = DateTime.now().toString().split('.')[0];
      final levelStr = level != null ? '[$level]' : '';
      final logLine = '$timestamp $levelStr $message\n';
      
      await _logFile!.writeAsString(
        logLine,
        mode: FileMode.append,
      );
    } catch (e) {
      // Ignora errori di scrittura
    }
  }
  
  /// Log info
  static Future<void> info(String message) async {
    await log(message, level: 'INFO');
  }
  
  /// Log warning
  static Future<void> warning(String message) async {
    await log(message, level: 'WARN');
  }
  
  /// Log error
  static Future<void> error(String message) async {
    await log(message, level: 'ERROR');
  }
  
  /// Log debug (solo se kDebugMode)
  static Future<void> debug(String message) async {
    if (kDebugMode) {
      await log(message, level: 'DEBUG');
    }
  }
  
  /// Ottieni path del file log
  static String? getLogPath() {
    return _logFile?.path;
  }
  
  /// Pulisci log vecchi (mantieni solo gli ultimi 10 file)
  static Future<void> cleanOldLogs() async {
    if (!_enabled || !Platform.isWindows) {
      return;
    }
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${appDir.path}/MyTeam');
      
      if (!await logDir.exists()) {
        return;
      }
      
      // Lista tutti i file log
      final logFiles = await logDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.txt'))
          .cast<File>()
          .toList();
      
      // Ordina per data di modifica (più recenti prima)
      logFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      
      // Mantieni solo gli ultimi 10 file, elimina gli altri
      if (logFiles.length > 10) {
        for (int i = 10; i < logFiles.length; i++) {
          await logFiles[i].delete();
        }
      }
    } catch (e) {
      // Ignora errori di pulizia
    }
  }
}

/// Wrapper per debugPrint che scrive anche su file (solo Windows release)
/// NOTA: Attualmente non usato. Mantenuto per uso futuro.
void fileDebugPrint(String? message, {int? wrapWidth}) {
  // Chiama debugPrint normale (funziona in debug mode)
  debugPrint(message, wrapWidth: wrapWidth);
  
  // Su Windows release, scrivi anche su file (se abilitato)
  if (FileLogger._enabled && Platform.isWindows && !kDebugMode && message != null) {
    FileLogger.log(message);
  }
}

