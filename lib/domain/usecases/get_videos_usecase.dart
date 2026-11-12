import '../entities/video.dart';
import '../repositories/video_repository.dart';

/// Get videos use case - Domain layer
class GetVideosUseCase {
  final VideoRepository repository;
  
  GetVideosUseCase(this.repository);
  
  /// Execute get videos
  Future<List<Video>> execute({
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
  }) async {
    return await repository.getVideos(
      page: page,
      limit: limit,
      search: search,
      sort: sort,
      status: status,
      playerIds: playerIds,
      trainingTypeIds: trainingTypeIds,
      teamIds: teamIds,
      recordedDateFrom: recordedDateFrom,
      recordedDateTo: recordedDateTo,
    );
  }
}

