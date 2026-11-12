import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../domain/entities/team.dart';

/// Team remote data source - Data layer
class TeamRemoteDataSource {
  final ApiClient apiClient;
  
  TeamRemoteDataSource(this.apiClient);
  
  /// Get all teams
  Future<List<Team>> getTeams({String? search}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      
      final response = await apiClient.dio.get(
        ApiConstants.teams,
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => _teamFromJson(json)).toList();
      } else {
        throw Exception('Get teams failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Get teams failed: $e');
    }
  }
  
  /// Get team by ID
  Future<Team> getTeamById(String id) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.teamDetail(id),
      );
      
      if (response.statusCode == 200) {
        return _teamFromJson(response.data);
      } else {
        throw Exception('Get team failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Get team failed: $e');
    }
  }
  
  /// Create a team
  Future<Team> createTeam({
    required String name,
    String? description,
    String? logoUrl,
    String? color,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.teams,
        data: {
          'name': name,
          'description': description,
          'logo_url': logoUrl,
          'color': color,
        },
      );
      
      if (response.statusCode == 201) {
        return _teamFromJson(response.data);
      } else {
        throw Exception('Create team failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Create team failed: $e');
    }
  }
  
  /// Update a team
  Future<Team> updateTeam({
    required String id,
    String? name,
    String? description,
    String? logoUrl,
    String? color,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (logoUrl != null) data['logo_url'] = logoUrl;
      if (color != null) data['color'] = color;
      
      final response = await apiClient.dio.put(
        ApiConstants.teamDetail(id),
        data: data,
      );
      
      if (response.statusCode == 200) {
        return _teamFromJson(response.data);
      } else {
        throw Exception('Update team failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Update team failed: $e');
    }
  }
  
  /// Delete a team
  Future<void> deleteTeam(String id) async {
    try {
      final response = await apiClient.dio.delete(
        ApiConstants.teamDetail(id),
      );
      
      if (response.statusCode != 204) {
        throw Exception('Delete team failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Delete team failed: $e');
    }
  }
  
  /// Add team to video
  Future<void> addTeamToVideo(String videoId, String teamId) async {
    try {
      final response = await apiClient.dio.post(
        '${ApiConstants.videos}/$videoId/teams',
        data: {'team_id': teamId},
      );
      
      if (response.statusCode != 201) {
        throw Exception('Add team to video failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Add team to video failed: $e');
    }
  }
  
  /// Remove team from video
  Future<void> removeTeamFromVideo(String videoId, String teamId) async {
    try {
      final response = await apiClient.dio.delete(
        '${ApiConstants.videos}/$videoId/teams/$teamId',
      );
      
      if (response.statusCode != 204) {
        throw Exception('Remove team from video failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Remove team from video failed: $e');
    }
  }
  
  Team _teamFromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      logoUrl: json['logo_url'] as String?,
      color: json['color'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      videoCount: json['video_count'] as int? ?? 0,
    );
  }
}

