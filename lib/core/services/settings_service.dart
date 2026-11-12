import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Service per gestire le impostazioni dell'app
/// Notifica i cambiamenti per permettere ai widget di reagire
class SettingsService extends ChangeNotifier {
  static const String _keyDebugMode = 'debug_mode';
  static const String _keyHardwareDecoding = 'hardware_decoding';
  
  static SharedPreferences? _prefs;
  static SettingsService? _instance;
  
  /// Istanza singleton
  static SettingsService get instance {
    _instance ??= SettingsService._();
    return _instance!;
  }
  
  SettingsService._();
  
  /// Inizializza il servizio
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// Verifica se il servizio è inizializzato
  static bool get isInitialized => _prefs != null;
  
  /// Abilita/disabilita modalità debug
  Future<bool> setDebugMode(bool enabled) async {
    if (_prefs == null) await initialize();
    final result = await _prefs!.setBool(_keyDebugMode, enabled);
    notifyListeners(); // Notifica i cambiamenti
    return result;
  }
  
  /// Abilita/disabilita modalità debug (metodo statico per compatibilità)
  static Future<bool> setDebugModeStatic(bool enabled) async {
    return await instance.setDebugMode(enabled);
  }
  
  /// Verifica se modalità debug è abilitata
  /// IMPORTANTE: legge sempre il valore corrente da SharedPreferences (non usa cache)
  bool getDebugMode() {
    if (_prefs == null) return false;
    // Leggi sempre il valore corrente da SharedPreferences
    // Questo garantisce che il valore sia sempre aggiornato
    final value = _prefs!.getBool(_keyDebugMode);
    // Se il valore è null, significa che non è mai stato impostato, quindi default è false
    return value ?? false;
  }
  
  /// Verifica se modalità debug è abilitata (metodo statico per compatibilità)
  static bool getDebugModeStatic() {
    return instance.getDebugMode();
  }
  
  /// Abilita/disabilita hardware decoding
  Future<bool> setHardwareDecoding(bool enabled) async {
    if (_prefs == null) await initialize();
    final result = await _prefs!.setBool(_keyHardwareDecoding, enabled);
    notifyListeners(); // Notifica i cambiamenti
    return result;
  }
  
  /// Abilita/disabilita hardware decoding (metodo statico per compatibilità)
  static Future<bool> setHardwareDecodingStatic(bool enabled) async {
    return await instance.setHardwareDecoding(enabled);
  }
  
  /// Verifica se hardware decoding è abilitato
  bool getHardwareDecoding() {
    if (_prefs == null) return false;
    return _prefs!.getBool(_keyHardwareDecoding) ?? false;
  }
  
  /// Verifica se hardware decoding è abilitato (metodo statico per compatibilità)
  static bool getHardwareDecodingStatic() {
    return instance.getHardwareDecoding();
  }
}

