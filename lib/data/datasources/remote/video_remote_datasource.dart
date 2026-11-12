import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../models/video_list_response.dart';
import '../../models/video_response.dart';

/// Video remote data source - Data layer
class VideoRemoteDataSource {
  final ApiClient apiClient;
  
  VideoRemoteDataSource(this.apiClient);
  
  /// Get list of videos with pagination, search, sorting, and filters
  Future<VideoListResponse> getVideos({
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
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    
    if (sort != null) {
      queryParams['sort'] = sort;
    }
    
    if (status != null) {
      queryParams['status'] = status;
    }
    
    // Filters
    if (playerIds != null && playerIds.isNotEmpty) {
      queryParams['player_ids'] = playerIds.join(',');
    }
    
    if (trainingTypeIds != null && trainingTypeIds.isNotEmpty) {
      queryParams['training_type_ids'] = trainingTypeIds.join(',');
    }
    
    if (teamIds != null && teamIds.isNotEmpty) {
      queryParams['team_ids'] = teamIds.join(',');
    }
    
    if (recordedDateFrom != null) {
      // Le date sono normalizzate con 12:00:00 UTC
      // Invia sempre in formato ISO 8601 UTC per evitare problemi di fuso orario
      queryParams['recorded_date_from'] = recordedDateFrom.toIso8601String();
    }
    
    if (recordedDateTo != null) {
      // Le date sono normalizzate con 12:00:00 UTC
      // Invia sempre in formato ISO 8601 UTC per evitare problemi di fuso orario
      queryParams['recorded_date_to'] = recordedDateTo.toIso8601String();
    }
    
    try {
      final response = await apiClient.dio.get(
        ApiConstants.videos,
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        return VideoListResponse.fromJson(response.data);
      } else {
        throw Exception('Get videos failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      // Use ApiClient's error message helper for user-friendly messages
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Get videos failed: $e');
    }
  }
  
  /// Get video by ID
  Future<VideoResponse> getVideoById(String id) async {
    try {
      final response = await apiClient.dio.get(
        '${ApiConstants.videos}/$id',
      );
      
      if (response.statusCode == 200) {
        return VideoResponse.fromJson(response.data);
      } else {
        throw Exception('Get video failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      // Use ApiClient's error message helper for user-friendly messages
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Get video failed: $e');
    }
  }
  
  /// Delete video
  Future<void> deleteVideo(String id) async {
    try {
      final response = await apiClient.dio.delete(
        '${ApiConstants.videos}/$id',
      );
      
      if (response.statusCode == 204) {
        return; // Success
      } else {
        throw Exception('Delete video failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Delete video failed: $e');
    }
  }
  
  /// Update video (title, description, recorded_date)
  Future<VideoResponse> updateVideo({
    required String id,
    String? title,
    String? description,
    DateTime? recordedDate,
  }) async {
    try {
      final formData = FormData();
      if (title != null) {
        formData.fields.add(MapEntry('title', title));
      }
      if (description != null) {
        formData.fields.add(MapEntry('description', description));
      }
      // Always send recorded_date: empty string to clear, or formatted date to set
      if (recordedDate != null) {
        // Format as YYYY-MM-DD (date only, no time) for better compatibility
        final dateStr = '${recordedDate.year}-${recordedDate.month.toString().padLeft(2, '0')}-${recordedDate.day.toString().padLeft(2, '0')}';
        formData.fields.add(MapEntry('recorded_date', dateStr));
      } else {
        // Send empty string to explicitly clear the date
        formData.fields.add(MapEntry('recorded_date', ''));
      }
      
      final response = await apiClient.dio.put(
        '${ApiConstants.videos}/$id',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
      
      if (response.statusCode == 200) {
        return VideoResponse.fromJson(response.data);
      } else {
        throw Exception('Update video failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Update video failed: $e');
    }
  }
  
  /// Update video title (deprecated, use updateVideo)
  Future<VideoResponse> updateVideoTitle({
    required String videoId,
    required String newTitle,
  }) async {
    try {
      final formData = FormData.fromMap({
        'title': newTitle,
      });
      
      final response = await apiClient.dio.put(
        '${ApiConstants.videos}/$videoId',
        data: formData,
      );
      
      if (response.statusCode == 200) {
        return VideoResponse.fromJson(response.data);
      } else {
        throw Exception('Update video title failed: ${response.statusCode} - ${response.data}');
      }
    } on DioException catch (e) {
      // Use ApiClient's error message helper for user-friendly messages
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Update video title failed: $e');
    }
  }
}

