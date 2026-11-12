import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../domain/entities/player.dart';

/// Player remote data source - Data layer
class PlayerRemoteDataSource {
  final ApiClient apiClient;
  
  PlayerRemoteDataSource(this.apiClient);
  
  /// Get all players
  Future<List<Player>> getPlayers({String? search}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      
      final response = await apiClient.dio.get(
        ApiConstants.players,
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => _playerFromJson(json)).toList();
      } else {
        throw Exception('Get players failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Get players failed: $e');
    }
  }
  
  /// Get player by ID
  Future<Player> getPlayerById(String id) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.playerDetail(id),
      );
      
      if (response.statusCode == 200) {
        return _playerFromJson(response.data);
      } else {
        throw Exception('Get player failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Get player failed: $e');
    }
  }
  
  /// Create a player
  Future<Player> createPlayer({
    required String name,
    String? description,
    String? photoUrl,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.players,
        data: {
          'name': name,
          'description': description,
          'photo_url': photoUrl,
        },
      );
      
      if (response.statusCode == 201) {
        return _playerFromJson(response.data);
      } else {
        throw Exception('Create player failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Create player failed: $e');
    }
  }
  
  /// Update a player
  Future<Player> updatePlayer({
    required String id,
    String? name,
    String? description,
    String? photoUrl,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (photoUrl != null) data['photo_url'] = photoUrl;
      
      final response = await apiClient.dio.put(
        ApiConstants.playerDetail(id),
        data: data,
      );
      
      if (response.statusCode == 200) {
        return _playerFromJson(response.data);
      } else {
        throw Exception('Update player failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Update player failed: $e');
    }
  }
  
  /// Delete a player
  Future<void> deletePlayer(String id) async {
    try {
      final response = await apiClient.dio.delete(
        ApiConstants.playerDetail(id),
      );
      
      if (response.statusCode != 204) {
        throw Exception('Delete player failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Delete player failed: $e');
    }
  }
  
  /// Add player to video
  Future<void> addPlayerToVideo(String videoId, String playerId) async {
    try {
      final response = await apiClient.dio.post(
        '${ApiConstants.videos}/$videoId/players',
        data: {'player_id': playerId},
      );
      
      if (response.statusCode != 201) {
        throw Exception('Add player to video failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Add player to video failed: $e');
    }
  }
  
  /// Remove player from video
  Future<void> removePlayerFromVideo(String videoId, String playerId) async {
    try {
      final response = await apiClient.dio.delete(
        '${ApiConstants.videos}/$videoId/players/$playerId',
      );
      
      if (response.statusCode != 204) {
        throw Exception('Remove player from video failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Remove player from video failed: $e');
    }
  }
  
  Player _playerFromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      photoUrl: json['photo_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      videoCount: json['video_count'] as int? ?? 0,
    );
  }
}

