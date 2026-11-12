import 'app_constants.dart';

/// API endpoints constants
class ApiConstants {
  // Base URL
  static String get baseUrl => AppConstants.baseUrl;
  
  // Video endpoints
  static String get videos => '${AppConstants.apiBaseUrl}/videos';
  
  // Helper methods for video endpoints
  static String videoDetail(String id) => '$videos/$id';
  static String videoThumbnail(String id) => '$videos/$id/thumbnail';
  static String videoDownload(String id) => '$videos/$id/download';
  static String videoStream(String id) => '$videos/$id/stream';
  
  // Chunked upload endpoints
  static String get chunkedUploadInit => '${AppConstants.apiBaseUrl}/videos/chunked/init';
  static String get chunkedUploadChunk => '${AppConstants.apiBaseUrl}/videos/chunked/chunk';
  static String get chunkedUploadComplete => '${AppConstants.apiBaseUrl}/videos/chunked/complete';
  
  // Upload queue endpoints (future)
  static String get uploadQueue => '${AppConstants.apiBaseUrl}/upload-queue';
  
  // Health check
  static String get health => '${AppConstants.baseUrl}/health';
  
  // Organization endpoints
  static String get players => '${AppConstants.apiBaseUrl}/players';
  static String get trainingTypes => '${AppConstants.apiBaseUrl}/training-types';
  static String get teams => '${AppConstants.apiBaseUrl}/teams';
  
  // Helper methods
  static String playerDetail(String id) => '$players/$id';
  static String trainingTypeDetail(String id) => '$trainingTypes/$id';
  static String teamDetail(String id) => '$teams/$id';
  static String videoNotes(String videoId) => '${videos}/$videoId/notes';
  static String videoNoteDetail(String videoId, String noteId) => '${videos}/$videoId/notes/$noteId';
}

