import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../models/video_response.dart';
import '../../../core/services/debug_logger.dart';

/// Chunked upload data source for bypassing Cloudflare 100MB limit
class ChunkedUploadDataSource {
  final ApiClient apiClient;
  
  ChunkedUploadDataSource(this.apiClient);
  
  /// Upload video file using chunked upload
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
    int maxRetries = 3,
  }) async {
    final fileSize = await videoFile.length();
    
    // Calcola numero di chunk necessari
    final totalChunks = (fileSize / AppConstants.chunkSize).ceil();
    
    DebugLogger.info('📦 [ChunkedUpload] Inizio upload chunked');
    DebugLogger.debug('   File size: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB');
    DebugLogger.debug('   Total chunks: $totalChunks');
    DebugLogger.debug('   Chunk size: ${(AppConstants.chunkSize / (1024 * 1024)).toStringAsFixed(2)} MB');
    
    // 1. Inizializza sessione upload
    final uploadId = await _initUpload(
      title: title,
      totalSize: fileSize,
      totalChunks: totalChunks,
      filename: videoFile.path.split('/').last,
      originalResolutionWidth: originalResolutionWidth,
      originalResolutionHeight: originalResolutionHeight,
      originalFramerate: originalFramerate,
      compressedFramerate: compressedFramerate,
      originalFileSize: originalFileSize,
      recordedDate: recordedDate,
    );
    
    DebugLogger.info('📦 [ChunkedUpload] Sessione inizializzata: $uploadId');
    
    // 2. Carica tutti i chunk
    final randomAccessFile = await videoFile.open();
    int totalSent = 0;
    
    try {
      for (int chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
        final chunkStart = chunkIndex * AppConstants.chunkSize;
        final chunkEnd = (chunkStart + AppConstants.chunkSize).clamp(0, fileSize);
        final currentChunkSize = chunkEnd - chunkStart;
        
        // Leggi chunk dal file
        await randomAccessFile.setPosition(chunkStart);
        final chunkData = await randomAccessFile.read(currentChunkSize);
        
        // Carica chunk con retry
        Exception? lastError;
        for (int attempt = 1; attempt <= maxRetries; attempt++) {
          try {
            DebugLogger.info('📦 [ChunkedUpload] Caricamento chunk ${chunkIndex + 1}/$totalChunks (attempt $attempt/$maxRetries)');
            
            await _uploadChunk(
              uploadId: uploadId,
              chunkIndex: chunkIndex,
              chunkData: chunkData,
            );
            
            totalSent += currentChunkSize;
            onProgress(totalSent, fileSize);
            
            DebugLogger.debug('✅ [ChunkedUpload] Chunk ${chunkIndex + 1}/$totalChunks caricato');
            break; // Successo, esci dal loop retry
          } catch (e) {
            lastError = e is Exception ? e : Exception(e.toString());
            if (attempt < maxRetries) {
              final delaySeconds = 1 << attempt;
              DebugLogger.warning('⚠️ [ChunkedUpload] Retry chunk ${chunkIndex + 1} dopo $delaySeconds secondi...');
              await Future.delayed(Duration(seconds: delaySeconds));
            }
          }
        }
        
        if (lastError != null && chunkIndex < totalChunks - 1) {
          throw Exception('Failed to upload chunk ${chunkIndex + 1}: $lastError');
        }
      }
    } finally {
      await randomAccessFile.close();
    }
    
    DebugLogger.info('📦 [ChunkedUpload] Tutti i chunk caricati, completamento upload...');
    
    // 3. Completa upload
    final videoResponse = await _completeUpload(uploadId: uploadId);
    
    DebugLogger.info('✅ [ChunkedUpload] Upload completato: ${videoResponse.id}');
    
    return videoResponse;
  }
  
  /// Inizializza sessione di chunked upload
  Future<String> _initUpload({
    required String title,
    required int totalSize,
    required int totalChunks,
    required String filename, // Può contenere path completo, il server lo normalizzerà
    int? originalResolutionWidth,
    int? originalResolutionHeight,
    double? originalFramerate,
    double? compressedFramerate,
    int? originalFileSize,
    DateTime? recordedDate,
  }) async {
    // Formatta la data come YYYY-MM-DD se presente
    String? recordedDateStr;
    if (recordedDate != null) {
      recordedDateStr = '${recordedDate.year}-${recordedDate.month.toString().padLeft(2, '0')}-${recordedDate.day.toString().padLeft(2, '0')}';
    }
    
    final formData = FormData.fromMap({
      'title': title,
      'total_size': totalSize,
      'total_chunks': totalChunks,
      'filename': filename,
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
    
    final response = await apiClient.dio.post(
      ApiConstants.chunkedUploadInit,
      data: formData,
      options: Options(
        validateStatus: (status) => true,
      ),
    );
    
    if (response.statusCode == 200) {
      return response.data['upload_id'] as String;
    } else {
      throw Exception('Failed to init chunked upload: ${response.statusCode} - ${response.data}');
    }
  }
  
  /// Carica un chunk
  Future<void> _uploadChunk({
    required String uploadId,
    required int chunkIndex,
    required List<int> chunkData,
  }) async {
    final multipartFile = MultipartFile.fromBytes(
      chunkData,
      filename: 'chunk_$chunkIndex',
    );
    
    final formData = FormData.fromMap({
      'upload_id': uploadId,
      'chunk_index': chunkIndex,
      'chunk': multipartFile,
    });
    
    final response = await apiClient.dio.post(
      ApiConstants.chunkedUploadChunk,
      data: formData,
      options: Options(
        validateStatus: (status) => true,
      ),
    );
    
    if (response.statusCode == 200) {
      final status = response.data['status'] as String;
      if (status != 'received' && status != 'already_received') {
        throw Exception('Chunk upload failed: $status');
      }
    } else {
      throw Exception('Failed to upload chunk: ${response.statusCode} - ${response.data}');
    }
  }
  
  /// Completa l'upload
  Future<VideoResponse> _completeUpload({
    required String uploadId,
  }) async {
    final formData = FormData.fromMap({
      'upload_id': uploadId,
    });
    
    final response = await apiClient.dio.post(
      ApiConstants.chunkedUploadComplete,
      data: formData,
      options: Options(
        validateStatus: (status) => true,
      ),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      return VideoResponse.fromJson(response.data);
    } else {
      throw Exception('Failed to complete chunked upload: ${response.statusCode} - ${response.data}');
    }
  }
}

