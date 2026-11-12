import '../../domain/entities/video.dart';
import '../../domain/repositories/video_repository.dart';
import '../datasources/remote/video_remote_datasource.dart';

/// Video repository implementation - Data layer
class VideoRepositoryImpl implements VideoRepository {
  final VideoRemoteDataSource remoteDataSource;
  
  VideoRepositoryImpl(this.remoteDataSource);
  
  @override
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
  }) async {
    final response = await remoteDataSource.getVideos(
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
    
    return response.items;
  }
  
  @override
  Future<Video> getVideoById(String id) async {
    final response = await remoteDataSource.getVideoById(id);
    return response.toEntity();
  }
  
  @override
  Future<Video> updateVideoTitle({
    required String videoId,
    required String newTitle,
  }) async {
    final response = await remoteDataSource.updateVideoTitle(
      videoId: videoId,
      newTitle: newTitle,
    );
    return response.toEntity();
  }
}

