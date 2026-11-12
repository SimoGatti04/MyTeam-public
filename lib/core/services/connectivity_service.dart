import 'package:connectivity_plus/connectivity_plus.dart';

/// Connectivity service for checking network connection
class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();
  
  /// Check if device is online
  static Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    // connectivity_plus 7.0 returns List<ConnectivityResult>
    return results.isNotEmpty && !results.contains(ConnectivityResult.none);
  }
  
  /// Stream of connectivity changes
  /// Note: connectivity_plus 7.0 returns List<ConnectivityResult>
  static Stream<List<ConnectivityResult>> connectivityStream() {
    return _connectivity.onConnectivityChanged;
  }
  
  /// Ensure device is online, throw exception if not
  static Future<void> ensureOnline() async {
    if (!await isOnline()) {
      throw ConnectivityException('No internet connection');
    }
  }
}

/// Connectivity exception
class ConnectivityException implements Exception {
  final String message;
  ConnectivityException(this.message);
  
  @override
  String toString() => 'ConnectivityException: $message';
}

