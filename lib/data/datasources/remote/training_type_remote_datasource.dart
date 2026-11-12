import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../domain/entities/training_type.dart';

/// TrainingType remote data source - Data layer
class TrainingTypeRemoteDataSource {
  final ApiClient apiClient;
  
  TrainingTypeRemoteDataSource(this.apiClient);
  
  /// Get all training types
  Future<List<TrainingType>> getTrainingTypes({String? search, String? category}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }
      
      final response = await apiClient.dio.get(
        ApiConstants.trainingTypes,
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => _trainingTypeFromJson(json)).toList();
      } else {
        throw Exception('Get training types failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Get training types failed: $e');
    }
  }
  
  /// Get training type by ID
  Future<TrainingType> getTrainingTypeById(String id) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.trainingTypeDetail(id),
      );
      
      if (response.statusCode == 200) {
        return _trainingTypeFromJson(response.data);
      } else {
        throw Exception('Get training type failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Get training type failed: $e');
    }
  }
  
  /// Create a training type
  Future<TrainingType> createTrainingType({
    required String name,
    String? description,
    String? category,
    String? color,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.trainingTypes,
        data: {
          'name': name,
          'description': description,
          'category': category,
          'color': color,
        },
      );
      
      if (response.statusCode == 201) {
        return _trainingTypeFromJson(response.data);
      } else {
        throw Exception('Create training type failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Create training type failed: $e');
    }
  }
  
  /// Update a training type
  Future<TrainingType> updateTrainingType({
    required String id,
    String? name,
    String? description,
    String? category,
    String? color,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (category != null) data['category'] = category;
      if (color != null) data['color'] = color;
      
      final response = await apiClient.dio.put(
        ApiConstants.trainingTypeDetail(id),
        data: data,
      );
      
      if (response.statusCode == 200) {
        return _trainingTypeFromJson(response.data);
      } else {
        throw Exception('Update training type failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Update training type failed: $e');
    }
  }
  
  /// Delete a training type
  Future<void> deleteTrainingType(String id) async {
    try {
      final response = await apiClient.dio.delete(
        ApiConstants.trainingTypeDetail(id),
      );
      
      if (response.statusCode != 204) {
        throw Exception('Delete training type failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Delete training type failed: $e');
    }
  }
  
  /// Add training type to video
  Future<void> addTrainingTypeToVideo(String videoId, String trainingTypeId) async {
    try {
      final response = await apiClient.dio.post(
        '${ApiConstants.videos}/$videoId/training-types',
        data: {'training_type_id': trainingTypeId},
      );
      
      if (response.statusCode != 201) {
        throw Exception('Add training type to video failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Add training type to video failed: $e');
    }
  }
  
  /// Remove training type from video
  Future<void> removeTrainingTypeFromVideo(String videoId, String trainingTypeId) async {
    try {
      final response = await apiClient.dio.delete(
        '${ApiConstants.videos}/$videoId/training-types/$trainingTypeId',
      );
      
      if (response.statusCode != 204) {
        throw Exception('Remove training type from video failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Remove training type from video failed: $e');
    }
  }
  
  TrainingType _trainingTypeFromJson(Map<String, dynamic> json) {
    return TrainingType(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      color: json['color'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      videoCount: json['video_count'] as int? ?? 0,
    );
  }
}

