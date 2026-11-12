import '../entities/video.dart';
import '../entities/upload_task.dart';
import '../repositories/upload_repository.dart';
import 'package:dio/dio.dart';

/// Upload video use case - Domain layer
class UploadVideoUseCase {
  final UploadRepository repository;
  
  UploadVideoUseCase(this.repository);
  
  /// Create upload task (prima di iniziare upload)
  Future<UploadTask> createUploadTask({
    required String localFilePath,
    required String title,
    int? originalFileSize,
  }) async {
    return await repository.createUploadTask(
      localFilePath: localFilePath,
      title: title,
      originalFileSize: originalFileSize,
    );
  }
  
  /// Create compression task (prima di iniziare compressione)
  Future<UploadTask> createCompressionTask({
    required String localFilePath,
    required String title,
    int? originalFileSize,
    int? totalFrames,
  }) async {
    return await repository.createCompressionTask(
      localFilePath: localFilePath,
      title: title,
      originalFileSize: originalFileSize,
      totalFrames: totalFrames,
    );
  }
  
  /// Update compression progress
  Future<void> updateCompressionProgress({
    required String taskId,
    required double progress,
    required int processedFrames,
    String? statusMessage,
  }) async {
    return await repository.updateCompressionProgress(
      taskId: taskId,
      progress: progress,
      processedFrames: processedFrames,
      statusMessage: statusMessage,
    );
  }
  
  /// Execute upload video
  Future<({Video video, UploadTask task})> execute({
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
    return await repository.uploadVideo(
      localFilePath: localFilePath,
      taskId: taskId,
      title: title,
      originalResolutionWidth: originalResolutionWidth,
      originalResolutionHeight: originalResolutionHeight,
      originalFramerate: originalFramerate,
      compressedFramerate: compressedFramerate,
      originalFileSize: originalFileSize,
      recordedDate: recordedDate,
      onProgress: onProgress,
      cancelToken: cancelToken, // Passa cancel token
    );
  }
  
  /// Get active uploads
  Future<List<UploadTask>> getActiveUploads() async {
    return await repository.getActiveUploads();
  }
  
  /// Get completed uploads (ultimi N, max 24h)
  Future<List<UploadTask>> getCompletedUploads({int limit = 5}) async {
    return await repository.getCompletedUploads(limit: limit);
  }
  
  /// Load saved upload tasks
  Future<List<UploadTask>> loadSavedUploadTasks() async {
    return await repository.loadSavedUploadTasks();
  }
  
  /// Cancel upload
  Future<void> cancelUpload(String taskId) async {
    return await repository.cancelUpload(taskId);
  }
  
  /// Get upload task by ID
  Future<UploadTask?> getUploadTask(String taskId) async {
    return await repository.getUploadTask(taskId);
  }
}

