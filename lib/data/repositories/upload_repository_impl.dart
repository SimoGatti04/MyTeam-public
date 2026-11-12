import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../domain/entities/video.dart';
import '../../domain/entities/upload_task.dart';
import '../../domain/repositories/upload_repository.dart';
import '../datasources/remote/upload_remote_datasource.dart';
import '../datasources/local/upload_local_datasource.dart';
import '../../core/services/debug_logger.dart';

/// Upload repository implementation - Data layer
class UploadRepositoryImpl implements UploadRepository {
  final UploadRemoteDataSource remoteDataSource;
  final UploadLocalDataSource localDataSource;
  
  // In-memory storage for upload tasks (cache)
  final Map<String, UploadTask> _uploadTasks = {};
  
  UploadRepositoryImpl(this.remoteDataSource, this.localDataSource);
  
  @override
  Future<UploadTask> createUploadTask({
    required String localFilePath,
    required String title,
    int? originalFileSize,
  }) async {
    final file = File(localFilePath);
    
    if (!await file.exists()) {
      throw Exception('File not found: $localFilePath');
    }
    
    // Create upload task
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final uploadTask = UploadTask(
      id: taskId,
      localFilePath: localFilePath,
      remoteFileName: file.path.split('/').last,
      totalBytes: originalFileSize ?? await file.length(),
      uploadedBytes: 0,
      status: UploadStatus.uploading,
      progress: 0.0,
      createdAt: DateTime.now(),
      startedAt: DateTime.now(),
    );
    _uploadTasks[taskId] = uploadTask;
    
    // Salva in persistenza
    await localDataSource.saveUploadTask(uploadTask);
    
    return uploadTask;
  }
  
  @override
  Future<UploadTask> createCompressionTask({
    required String localFilePath,
    required String title,
    int? originalFileSize,
    int? totalFrames,
  }) async {
    final file = File(localFilePath);
    
    if (!await file.exists()) {
      throw Exception('File not found: $localFilePath');
    }
    
    // Create compression task
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final compressionTask = UploadTask(
      id: taskId,
      localFilePath: localFilePath,
      remoteFileName: file.path.split('/').last,
      totalBytes: originalFileSize ?? await file.length(),
      uploadedBytes: 0,
      status: UploadStatus.compressing,
      progress: 0.0,
      createdAt: DateTime.now(),
      startedAt: DateTime.now(),
    );
    _uploadTasks[taskId] = compressionTask;
    
    // Salva in persistenza
    await localDataSource.saveUploadTask(compressionTask);
    
    return compressionTask;
  }
  
  @override
  Future<void> updateCompressionProgress({
    required String taskId,
    required double progress,
    required int processedFrames,
    String? statusMessage,
  }) async {
    // Recupera task dalla cache o persistenza
    UploadTask? task = _uploadTasks[taskId];
    if (task == null) {
      task = await localDataSource.getUploadTask(taskId);
      if (task == null) {
        DebugLogger.warning('⚠️ [Compression] Task non trovato: $taskId');
        return;
      }
      _uploadTasks[taskId] = task;
    }
    
    // Aggiorna task
    final updatedTask = task.copyWith(
      progress: progress,
      uploadedBytes: processedFrames, // Usa processedFrames come uploadedBytes per tracking
    );
    _uploadTasks[taskId] = updatedTask;
    
    // Salva in persistenza
    await localDataSource.updateUploadTask(updatedTask);
  }
  
  @override
  Future<({Video video, UploadTask task})> uploadVideo({
    required String localFilePath,
    required String taskId, // ID del task creato precedentemente
    required String title,
    int? originalResolutionWidth,
    int? originalResolutionHeight,
    double? originalFramerate,
    double? compressedFramerate,
    int? originalFileSize,
    DateTime? recordedDate,
    required Function(int sent, int total) onProgress,
    CancelToken? cancelToken, // Token per cancellazione
  }) async {
    final file = File(localFilePath);
    
    if (!await file.exists()) {
      throw Exception('File not found: $localFilePath');
    }
    
    // IMPORTANTE: Verifica dimensione file compresso (non originale)
    final compressedFileSize = await file.length();
    DebugLogger.info('📤 [Upload] Repository - File da caricare:');
    DebugLogger.debug('   Path: $localFilePath');
    DebugLogger.debug('   Dimensione compressa: ${compressedFileSize} bytes (${(compressedFileSize / (1024 * 1024)).toStringAsFixed(2)} MB)');
    DebugLogger.debug('   Dimensione originale: ${originalFileSize ?? "N/A"} bytes (${originalFileSize != null ? (originalFileSize! / (1024 * 1024)).toStringAsFixed(2) : "N/A"} MB)');
    
    // Recupera task creato precedentemente
    UploadTask? uploadTask = _uploadTasks[taskId];
    if (uploadTask == null) {
      // Se non trovato in cache, carica da persistenza
      uploadTask = await localDataSource.getUploadTask(taskId);
      if (uploadTask == null) {
        throw Exception('Upload task not found: $taskId');
      }
      _uploadTasks[taskId] = uploadTask;
    }
    
    try {
      // Upload to server - passa il file compresso (non originale)
      final videoResponse = await remoteDataSource.uploadVideo(
        videoFile: file,
        title: title,
        originalResolutionWidth: originalResolutionWidth,
        originalResolutionHeight: originalResolutionHeight,
        originalFramerate: originalFramerate,
        compressedFramerate: compressedFramerate,
        originalFileSize: originalFileSize,
        recordedDate: recordedDate,
        onProgress: (sent, total) {
          // Update upload task progress
          if (uploadTask == null) {
            return; // Safety check
          }
          
          final updatedTask = uploadTask!.copyWith(
            uploadedBytes: sent,
            progress: total > 0 ? sent / total : 0.0,
          );
          _uploadTasks[taskId] = updatedTask;
          uploadTask = updatedTask; // Aggiorna variabile locale
          
          // Salva in persistenza (non bloccante)
          localDataSource.updateUploadTask(updatedTask).catchError((e) {
            // Ignora errori di persistenza durante upload
            DebugLogger.warning('Error saving upload progress: $e');
          });
          
          // Call original progress callback
          onProgress(sent, total);
        },
      );
      
      // Update task as completed
      if (uploadTask == null) {
        throw Exception('Upload task is null after upload');
      }
      final completedTask = uploadTask!.copyWith(
        videoId: videoResponse.id,
        status: UploadStatus.completed,
        progress: 1.0,
        completedAt: DateTime.now(),
      );
      _uploadTasks[taskId] = completedTask;
      
      // Salva in persistenza
      await localDataSource.updateUploadTask(completedTask);
      
      return (video: videoResponse.toEntity(), task: completedTask);
    } catch (e) {
      // Update task as error
      if (uploadTask == null) {
        rethrow; // Se il task è null, non possiamo aggiornarlo
      }
      final errorTask = uploadTask!.copyWith(
        status: UploadStatus.error,
        errorMessage: e.toString(),
      );
      _uploadTasks[taskId] = errorTask;
      
      // Salva in persistenza
      await localDataSource.updateUploadTask(errorTask);
      
      rethrow;
    }
  }
  
  @override
  Future<UploadTask?> getUploadTask(String taskId) async {
    // Prova prima dalla cache
    if (_uploadTasks.containsKey(taskId)) {
      return _uploadTasks[taskId];
    }
    
    // Carica da persistenza
    final task = await localDataSource.getUploadTask(taskId);
    if (task != null) {
      _uploadTasks[taskId] = task;
    }
    return task;
  }
  
  @override
  Future<void> cancelUpload(String taskId) async {
    final task = _uploadTasks[taskId] ?? await localDataSource.getUploadTask(taskId);
    if (task != null) {
      final cancelledTask = task.copyWith(
        status: UploadStatus.cancelled,
      );
      _uploadTasks[taskId] = cancelledTask;
      
      // IMPORTANTE: rimuovi dalla lista task attivi quando viene cancellata
      // Questo evita che riappaia come attiva quando si ricarica
      await localDataSource.removeUploadTask(taskId);
      
      DebugLogger.info('✅ [Cancel] Task $taskId cancellata e rimossa dalla persistenza');
    }
  }
  
  @override
  Future<List<UploadTask>> getActiveUploads() async {
    // Carica da persistenza (include anche quelli in memoria)
    final persistedTasks = await localDataSource.getActiveUploadTasks();
    
    // Unisci con task in memoria
    final allTasks = <String, UploadTask>{};
    for (final task in persistedTasks) {
      allTasks[task.id] = task;
    }
    for (final task in _uploadTasks.values) {
      if (task.status == UploadStatus.uploading || 
          task.status == UploadStatus.compressing) {
        allTasks[task.id] = task;
      }
    }
    
    return allTasks.values.toList();
  }
  
  @override
  /// Get completed upload tasks (ultimi N, max 24h)
  Future<List<UploadTask>> getCompletedUploads({int limit = 5}) async {
    return await localDataSource.getCompletedUploadTasks(limit: limit);
  }
  
  @override
  /// Load all saved upload tasks
  Future<List<UploadTask>> loadSavedUploadTasks() async {
    final tasks = await localDataSource.getAllUploadTasks();
    
    // Aggiorna cache
    for (final task in tasks) {
      _uploadTasks[task.id] = task;
    }
    
    return tasks;
  }
}

