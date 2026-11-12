import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../domain/entities/note.dart';

/// Note remote data source - Data layer
class NoteRemoteDataSource {
  final ApiClient apiClient;
  
  NoteRemoteDataSource(this.apiClient);
  
  /// Get all notes for a video
  Future<List<Note>> getVideoNotes(String videoId) async {
    try {
      final response = await apiClient.dio.get(
        '${ApiConstants.videos}/$videoId/notes',
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => _noteFromJson(json)).toList();
      } else {
        throw Exception('Get notes failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Get notes failed: $e');
    }
  }
  
  /// Create a note
  Future<Note> createNote({
    required String videoId,
    required String content,
    int? timestamp,
  }) async {
    try {
      final response = await apiClient.dio.post(
        '${ApiConstants.videos}/$videoId/notes',
        data: {
          'content': content,
          'timestamp': timestamp,
          'is_private': true,
        },
      );
      
      if (response.statusCode == 201) {
        return _noteFromJson(response.data);
      } else {
        throw Exception('Create note failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Create note failed: $e');
    }
  }
  
  /// Update a note
  Future<Note> updateNote({
    required String videoId,
    required String noteId,
    String? content,
    int? timestamp,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (content != null) data['content'] = content;
      if (timestamp != null) data['timestamp'] = timestamp;
      
      final response = await apiClient.dio.put(
        '${ApiConstants.videos}/$videoId/notes/$noteId',
        data: data,
      );
      
      if (response.statusCode == 200) {
        return _noteFromJson(response.data);
      } else {
        throw Exception('Update note failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Update note failed: $e');
    }
  }
  
  /// Delete a note
  Future<void> deleteNote(String videoId, String noteId) async {
    try {
      final response = await apiClient.dio.delete(
        '${ApiConstants.videos}/$videoId/notes/$noteId',
      );
      
      if (response.statusCode != 204) {
        throw Exception('Delete note failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.getErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Delete note failed: $e');
    }
  }
  
  Note _noteFromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      videoId: json['video_id'] as String,
      content: json['content'] as String,
      timestamp: json['timestamp'] as int?,
      isPrivate: json['is_private'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}

