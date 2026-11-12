import 'package:dio/dio.dart';
import 'debug_logger.dart';

/// Service per gestire la cancellazione delle richieste di upload
class UploadCancellationService {
  static final Map<String, CancelToken> _activeUploads = {};
  
  /// Crea un CancelToken per un upload
  static CancelToken createCancelToken(String taskId) {
    // Se esiste già, cancella quello precedente
    if (_activeUploads.containsKey(taskId)) {
      _activeUploads[taskId]!.cancel('Upload cancelled by user');
      _activeUploads.remove(taskId);
    }
    
    final cancelToken = CancelToken();
    _activeUploads[taskId] = cancelToken;
    DebugLogger.info('Created cancel token for upload: $taskId');
    return cancelToken;
  }
  
  /// Cancella un upload specifico
  static void cancelUpload(String taskId) {
    final cancelToken = _activeUploads[taskId];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('Upload cancelled by user');
      DebugLogger.info('Cancelled upload: $taskId');
    }
    _activeUploads.remove(taskId);
  }
  
  /// Cancella tutti gli upload attivi
  static void cancelAllUploads() {
    for (final entry in _activeUploads.entries) {
      if (!entry.value.isCancelled) {
        entry.value.cancel('All uploads cancelled');
      }
    }
    DebugLogger.info('Cancelled all active uploads (${_activeUploads.length})');
    _activeUploads.clear();
  }
  
  /// Rimuove un cancel token (quando upload completa)
  static void removeCancelToken(String taskId) {
    _activeUploads.remove(taskId);
  }
  
  /// Verifica se un upload è stato cancellato
  static bool isCancelled(String taskId) {
    final cancelToken = _activeUploads[taskId];
    return cancelToken?.isCancelled ?? false;
  }
}

