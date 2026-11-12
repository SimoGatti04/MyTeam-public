import '../entities/upload_task.dart';
import '../entities/video.dart';
import 'package:dio/dio.dart';

/// Upload repository interface - Domain layer
abstract class UploadRepository {
  /// Create upload task (prima di iniziare upload)
  /// Restituisce il task creato immediatamente
  Future<UploadTask> createUploadTask({
    required String localFilePath,
    required String title,
    int? originalFileSize,
  });
  
  /// Create compression task (prima di iniziare compressione)
  /// Restituisce il task creato immediatamente
  Future<UploadTask> createCompressionTask({
    required String localFilePath,
    required String title,
    int? originalFileSize,
    int? totalFrames,
  });
  
  /// Update compression progress
  Future<void> updateCompressionProgress({
    required String taskId,
    required double progress,
    required int processedFrames,
    String? statusMessage,
  });
  
  /// Upload video to server
  /// Returns Video entity if successful
  /// Also returns the upload task created
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
  });
  
  /// Get upload task by ID
  Future<UploadTask?> getUploadTask(String taskId);
  
  /// Cancel upload task
  Future<void> cancelUpload(String taskId);
  
  /// Get all active upload tasks
  Future<List<UploadTask>> getActiveUploads();
  
  /// Get completed upload tasks (ultimi N)
  Future<List<UploadTask>> getCompletedUploads({int limit = 10});
  
  /// Load all saved upload tasks
  Future<List<UploadTask>> loadSavedUploadTasks();
}

