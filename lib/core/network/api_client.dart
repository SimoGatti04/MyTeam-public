import 'dart:io';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../services/debug_logger.dart';

/// API client for server communication
class ApiClient {
  late final Dio _dio;
  
  ApiClient() {
    // Timeout ottimizzati per piattaforma
    // Android/Windows: timeout più lunghi per gestire reti instabili
    final connectTimeout = (Platform.isAndroid || Platform.isWindows)
        ? const Duration(seconds: 60)  // Android/Windows: 60s per reti instabili
        : const Duration(seconds: 30);  // Altri: 30s
    
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: const Duration(hours: 24), // For large uploads
      sendTimeout: const Duration(hours: 24), // For large uploads
      // IMPORTANTE: Non impostare Content-Type di default
      // Dio lo imposterà automaticamente per multipart/form-data
      headers: {
        'Accept': 'application/json',
      },
    ));
    
    // Add error interceptor for better error messages
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Log richieste di upload per debugging (DebugLogger gestisce già kDebugMode)
        if (options.method == 'POST' && options.path.contains('/videos')) {
          DebugLogger.debug('🌐 [API] Request: ${options.method} ${options.path}');
          DebugLogger.debug('   Headers: ${options.headers}');
          if (options.data is FormData) {
            final formData = options.data as FormData;
            DebugLogger.debug('   FormData fields: ${formData.fields.length}');
            DebugLogger.debug('   FormData files: ${formData.files.length}');
            for (final file in formData.files) {
              DebugLogger.debug('     File: ${file.key} - ${file.value.filename}');
            }
          }
        }
        handler.next(options);
      },
      onError: (error, handler) {
        // Log dettagliato degli errori (sempre per errori critici)
        if (error.type != DioExceptionType.cancel) {
          DebugLogger.error('❌ [API] Error: ${error.type}');
          DebugLogger.debug('   Message: ${error.message}');
          DebugLogger.debug('   Response: ${error.response?.statusCode} - ${error.response?.data}');
          DebugLogger.debug('   Request: ${error.requestOptions.method} ${error.requestOptions.path}');
          
          // Log errori specifici per upload
          if (error.requestOptions.path.contains('/videos') && error.requestOptions.method == 'POST') {
            DebugLogger.warning('   ⚠️ [API] Errore durante upload video');
            if (error.type == DioExceptionType.unknown && error.message == null) {
              DebugLogger.warning('   ⚠️ [API] Unknown error senza messaggio - possibile timeout o problema di connessione');
            }
          }
        }
        handler.next(error);
      },
    ));
  }
  
  Dio get dio => _dio;
  
  /// Health check
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get(ApiConstants.health);
      return response.statusCode == 200;
    } on DioException {
      // Silently fail health check
      return false;
    } catch (_) {
      return false;
    }
  }
  
  /// Get user-friendly error message
  static String getErrorMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Timeout di connessione. Verifica la tua connessione internet.';
      case DioExceptionType.sendTimeout:
        return 'Timeout durante l\'invio dei dati.';
      case DioExceptionType.receiveTimeout:
        return 'Timeout durante la ricezione dei dati.';
      case DioExceptionType.badResponse:
        return 'Errore del server: ${error.response?.statusCode}';
      case DioExceptionType.cancel:
        return 'Richiesta annullata.';
      case DioExceptionType.connectionError:
        return 'Errore di connessione. Verifica che il server sia raggiungibile.';
      case DioExceptionType.badCertificate:
        return 'Errore certificato SSL. Verifica la configurazione del server.';
      case DioExceptionType.unknown:
        if (error.message != null && error.message!.contains('Failed host lookup')) {
          return 'Impossibile raggiungere il server. Verifica l\'URL: ${ApiConstants.baseUrl}';
        }
        return 'Errore sconosciuto: ${error.message ?? "Nessun dettaglio disponibile"}';
    }
  }
}

