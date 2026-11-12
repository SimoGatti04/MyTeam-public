import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'settings_service.dart';

/// Logger per modalità debug con buffer circolare
/// Salva e mostra log solo se la modalità debug è attiva (kDebugMode o SettingsService.getDebugMode())
class DebugLogger {
  static const int _maxLogs = 500; // Massimo numero di log da mantenere
  static final Queue<String> _logs = Queue<String>();
  static final List<Function(String)> _listeners = [];
  
  /// Verifica se la modalità debug è attiva
  /// Priorità: se SettingsService è inizializzato, usa solo il toggle (ignora kDebugMode)
  /// Se non è inizializzato, usa kDebugMode come fallback SOLO se non è stato ancora impostato
  static bool get _isDebugModeActive {
    // Se SettingsService è inizializzato, usa solo il toggle (ha priorità su kDebugMode)
    if (SettingsService.isInitialized) {
      final toggleValue = SettingsService.getDebugModeStatic();
      // Se il toggle è esplicitamente disattivato, non usare kDebugMode come fallback
      return toggleValue;
    }
    // Se non è inizializzato, usa kDebugMode come fallback
    // Questo è necessario solo durante l'inizializzazione dell'app
    return kDebugMode;
  }
  
  /// Aggiunge un log (solo se debug mode è attivo)
  static void log(String message, {String level = 'INFO'}) {
    // Se debug mode non è attivo, esci immediatamente senza fare nulla
    // NON stampare su console, NON salvare in buffer, NON notificare listeners
    if (!_isDebugModeActive) {
      return;
    }
    
    final timestamp = DateTime.now().toString().substring(11, 19); // HH:mm:ss
    final logEntry = '[$timestamp] [$level] $message';
    
    // Aggiungi al buffer solo se debug mode è attivo
    _logs.add(logEntry);
    
    // Mantieni solo gli ultimi _maxLogs
    if (_logs.length > _maxLogs) {
      _logs.removeFirst();
    }
    
    // Notifica listeners solo se debug mode è attivo
    for (final listener in _listeners) {
      listener(logEntry);
    }
    
    // Log su debugPrint (solo se debug mode è attivo)
    // IMPORTANTE: verifica di nuovo _isDebugModeActive prima di chiamare debugPrint
    // perché potrebbe essere cambiato tra il check iniziale e qui
  }
  
  /// Pulisce tutti i log quando debug mode viene disattivato
  /// Chiamato quando l'utente disattiva debug mode dalle impostazioni
  static void clearLogsOnDebugModeDisabled() {
    _logs.clear();
    // Notifica listeners per pulire l'overlay
    for (final listener in _listeners) {
      listener('');
    }
  }
  
  /// Log info
  static void info(String message) => log(message, level: 'INFO');
  
  /// Log warning
  static void warning(String message) => log(message, level: 'WARN');
  
  /// Log error
  static void error(String message) => log(message, level: 'ERROR');
  
  /// Log debug
  static void debug(String message) => log(message, level: 'DEBUG');
  
  /// Ottiene tutti i log (solo se debug mode è attivo, altrimenti lista vuota)
  static List<String> getLogs() {
    if (!_isDebugModeActive) {
      return [];
    }
    return _logs.toList();
  }
  
  /// Pulisce i log (solo se debug mode è attivo)
  static void clear() {
    if (!_isDebugModeActive) {
      return;
    }
    _logs.clear();
    for (final listener in _listeners) {
      listener('');
    }
  }
  
  /// Aggiunge un listener per nuovi log
  static void addListener(Function(String) listener) {
    _listeners.add(listener);
  }
  
  /// Rimuove un listener
  static void removeListener(Function(String) listener) {
    _listeners.remove(listener);
  }
}

