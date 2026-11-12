import '../entities/video.dart';

/// Video repository interface - Domain layer
abstract class VideoRepository {
  /// Get list of videos with pagination, search, sorting, and filters
  Future<List<Video>> getVideos({
    int page = 1,
    int limit = 20,
    String? search,
    String? sort,
    String? status,
    List<String>? playerIds,
    List<String>? trainingTypeIds,
    List<String>? teamIds,
    DateTime? recordedDateFrom,
    DateTime? recordedDateTo,
  });
  
  /// Get video by ID
  Future<Video> getVideoById(String id);
  
  /// Update video title
  Future<Video> updateVideoTitle({
    required String videoId,
    required String newTitle,
  });
}

