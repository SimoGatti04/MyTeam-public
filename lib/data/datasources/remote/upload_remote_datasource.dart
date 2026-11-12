import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../models/video_response.dart';
import 'chunked_upload_datasource.dart';
import '../../../core/services/debug_logger.dart';

/// Upload remote data source - Data layer
class UploadRemoteDataSource {
  final ApiClient apiClient;
  final ChunkedUploadDataSource? _chunkedUploadDataSource;
  
  UploadRemoteDataSource(this.apiClient)
      : _chunkedUploadDataSource = ChunkedUploadDataSource(apiClient);
  
  /// Upload video file to server with retry logic
  /// Usa chunked upload automaticamente se il file è >100MB
  Future<VideoResponse> uploadVideo({
    required File videoFile,
    required String title,
    int? originalResolutionWidth,
    int? originalResolutionHeight,
    double? originalFramerate,
    double? compressedFramerate,
    int? originalFileSize,
    DateTime? recordedDate,
    required Function(int sent, int total) onProgress,
    int maxRetries = 3, // Numero massimo di retry
    CancelToken? cancelToken, // Token per cancellazione upload
  }) async {
    // Ottieni dimensione file per validazione
    final fileSize = await videoFile.length();
    
    // Verifica dimensione file prima di procedere
    if (fileSize > AppConstants.maxUploadSize) {
      throw Exception('File troppo grande: ${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB. Dimensione massima: ${(AppConstants.maxUploadSize / (1024 * 1024 * 1024)).toStringAsFixed(0)} GB');
    }
    
    // Usa chunked upload se il file è >100MB (limite Cloudflare)
    if (fileSize > AppConstants.chunkedUploadThreshold) {
      DebugLogger.info('📦 [Upload] File >100MB, uso chunked upload');
      return await _chunkedUploadDataSource!.uploadVideo(
        videoFile: videoFile,
        title: title,
        originalResolutionWidth: originalResolutionWidth,
        originalResolutionHeight: originalResolutionHeight,
        originalFramerate: originalFramerate,
        compressedFramerate: compressedFramerate,
        originalFileSize: originalFileSize,
        recordedDate: recordedDate,
        onProgress: onProgress,
        maxRetries: maxRetries,
      );
    }
    
    // Upload normale per file <100MB
    
    // Log URL e configurazione
    final uploadUrl = ApiConstants.videos;
    DebugLogger.debug('📤 [Upload] URL upload: $uploadUrl');
    DebugLogger.debug('📤 [Upload] Base URL: ${ApiConstants.baseUrl}');
    
    // Crea MultipartFile per upload
    final multipartFile = await MultipartFile.fromFile(
      videoFile.path,
      filename: videoFile.path.split('/').last,
    );
    
    // Formatta la data come YYYY-MM-DD se presente
    String? recordedDateStr;
    if (recordedDate != null) {
      recordedDateStr = '${recordedDate.year}-${recordedDate.month.toString().padLeft(2, '0')}-${recordedDate.day.toString().padLeft(2, '0')}';
      DebugLogger.info('📅 [Upload] Data registrazione formattata per invio: $recordedDateStr');
    } else {
      DebugLogger.info('📅 [Upload] Nessuna data registrazione da inviare');
    }
    
    final formData = FormData.fromMap({
      'file': multipartFile,
      'title': title,
      if (originalResolutionWidth != null)
        'original_resolution_width': originalResolutionWidth,
      if (originalResolutionHeight != null)
        'original_resolution_height': originalResolutionHeight,
      if (originalFramerate != null)
        'original_framerate': originalFramerate,
      if (compressedFramerate != null)
        'compressed_framerate': compressedFramerate,
      if (originalFileSize != null)
        'original_file_size': originalFileSize,
      if (recordedDateStr != null)
        'recorded_date': recordedDateStr,
    });
    
    DebugLogger.debug('📤 [Upload] FormData keys: ${formData.fields.map((e) => e.key).toList()}');
    
    // Retry logic con exponential backoff
    Exception? lastError;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // Calcola timeout basato sulla dimensione del file
        // Assumendo velocità minima di 0.5 MB/s (molto conservativo per reti lente)
        // Aggiungi 120 secondi di buffer per overhead
        final estimatedUploadTime = Duration(
          seconds: ((fileSize / (1024 * 1024) / 0.5).round() + 120).clamp(600, 86400), // Min 10 minuti, max 24 ore
        );
        
        DebugLogger.info('📤 [Upload] Tentativo $attempt/$maxRetries');
        DebugLogger.debug('   File size: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB');
        DebugLogger.debug('   Timeout: ${estimatedUploadTime.inMinutes} minuti (${estimatedUploadTime.inSeconds} secondi)');
        
        final response = await apiClient.dio.post(
          ApiConstants.videos,
          data: formData,
          onSendProgress: onProgress,
          cancelToken: cancelToken, // Supporto cancellazione
          options: Options(
            sendTimeout: estimatedUploadTime,
            receiveTimeout: estimatedUploadTime,
            validateStatus: (status) => true,
            // IMPORTANTE: Lascia che Dio imposti automaticamente Content-Type per multipart
            // Non sovrascrivere Content-Type manualmente
            contentType: null, // Dio lo imposterà automaticamente per FormData
          ),
        );
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          DebugLogger.info('✅ [Upload] Upload completato con successo!');
          return VideoResponse.fromJson(response.data);
        } else {
          throw Exception('Upload failed: ${response.statusCode} - ${response.data}');
        }
      } on DioException catch (e) {
        lastError = e;
        
        DebugLogger.error('❌ [Upload] Errore tentativo $attempt: ${e.type}');
        DebugLogger.debug('   Message: ${e.message}');
        DebugLogger.debug('   Status: ${e.response?.statusCode}');
        DebugLogger.debug('   Response: ${e.response?.data}');
        
        // Se è un errore 413, fornisci messaggio chiaro
        // Nota: Questo non dovrebbe mai accadere perché chunked upload viene usato automaticamente per file >100MB
        if (e.response?.statusCode == 413) {
          throw Exception('File troppo grande. Chunked upload dovrebbe essere usato automaticamente per file >100MB. Se vedi questo errore, contatta il supporto.');
        }
        
        // Retry per errori di connessione/timeout/unknown (potrebbe essere timeout nascosto)
        final isRetryable = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.connectionError ||
            (e.type == DioExceptionType.unknown && e.message == null); // Unknown senza messaggio = probabile timeout
        
        if (isRetryable && attempt < maxRetries) {
          final delaySeconds = 1 << attempt; // 2, 4, 8, 16 secondi
          DebugLogger.warning('⚠️ [Upload] Retry dopo $delaySeconds secondi...');
          await Future.delayed(Duration(seconds: delaySeconds));
          continue;
        }
        
        // Se non è retryable o abbiamo finito i retry, rilancia con messaggio dettagliato
        if (e.type == DioExceptionType.unknown && e.message == null) {
          throw Exception('Upload fallito: timeout o connessione interrotta. Verifica la connessione internet e riprova.');
        }
        
        throw Exception('Upload failed: ${e.response?.statusCode ?? e.type} - ${e.response?.data ?? e.message ?? "Errore sconosciuto"}');
      }
    }
    
    throw lastError ?? Exception('Upload failed dopo $maxRetries tentativi');
  }
}

