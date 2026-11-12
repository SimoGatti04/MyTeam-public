import '../../domain/entities/video.dart';

/// Video response model - Data layer (DTO from server)
class VideoResponse {
  final String id;
  final String title;
  final String? description;
  final String filename;
  final String filePath;
  final int fileSize;
  final String fileFormat;
  final int? duration; // seconds
  final int? width;
  final int? height;
  final String? thumbnailPath;
  final String status; // processing, ready, error
  final Map<String, dynamic>? videoMetadata;
  final int? originalResolutionWidth;
  final int? originalResolutionHeight;
  final double? originalFramerate;
  final double? compressedFramerate;
  final int? originalFileSize;
    final double? compressionRatio;
    final DateTime createdAt;
    final DateTime? recordedDate; // Data di realizzazione (modificabile)
    final DateTime updatedAt;
    final List<String>? playerIds; // Lista ID giocatori associati
    final List<String>? trainingTypeIds; // Lista ID training types associati
    final List<String>? teamIds; // Lista ID teams associati
  
  VideoResponse({
    required this.id,
    required this.title,
    this.description,
    required this.filename,
    required this.filePath,
    required this.fileSize,
    required this.fileFormat,
    this.duration,
    this.width,
    this.height,
    this.thumbnailPath,
    required this.status,
    this.videoMetadata,
    this.originalResolutionWidth,
    this.originalResolutionHeight,
    this.originalFramerate,
    this.compressedFramerate,
    this.originalFileSize,
    this.compressionRatio,
    required this.createdAt,
    this.recordedDate,
    required this.updatedAt,
    this.playerIds,
    this.trainingTypeIds,
    this.teamIds,
  });
  
  /// Convert to domain entity
  Video toEntity() {
    return Video(
      id: id,
      title: title,
      description: description,
      fileName: filename,
      fileSize: fileSize,
      fileFormat: fileFormat,
      duration: duration != null ? Duration(seconds: duration!) : null,
      width: width,
      height: height,
      thumbnailUrl: thumbnailPath,
      uploadedAt: createdAt,
      recordedAt: recordedDate,
      lastModifiedAt: updatedAt,
      status: _parseStatus(status),
      metadata: videoMetadata,
      originalResolutionWidth: originalResolutionWidth,
      originalResolutionHeight: originalResolutionHeight,
      originalFramerate: originalFramerate,
      compressedFramerate: compressedFramerate,
      originalFileSize: originalFileSize,
      compressionRatio: compressionRatio,
      playerIds: playerIds,
      trainingTypeIds: trainingTypeIds,
      teamIds: teamIds,
    );
  }
  
  VideoStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'processing':
        return VideoStatus.processing;
      case 'ready':
        return VideoStatus.ready;
      case 'error':
        return VideoStatus.error;
      case 'deleted':
        return VideoStatus.deleted;
      default:
        return VideoStatus.processing;
    }
  }
  
  /// Create from JSON
  factory VideoResponse.fromJson(Map<String, dynamic> json) {
    return VideoResponse(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      filename: json['filename'] as String,
      filePath: json['file_path'] as String,
      fileSize: json['file_size'] as int,
      fileFormat: json['file_format'] as String,
      duration: json['duration'] as int?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      thumbnailPath: json['thumbnail_path'] as String?,
      status: json['status'] as String,
      videoMetadata: json['video_metadata'] as Map<String, dynamic>?,
      originalResolutionWidth: json['original_resolution_width'] as int?,
      originalResolutionHeight: json['original_resolution_height'] as int?,
      originalFramerate: (json['original_framerate'] as num?)?.toDouble(),
      compressedFramerate: (json['compressed_framerate'] as num?)?.toDouble(),
      originalFileSize: json['original_file_size'] as int?,
      compressionRatio: (json['compression_ratio'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      recordedDate: json['recorded_date'] != null 
          ? DateTime.parse(json['recorded_date'] as String)
          : null,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      playerIds: json['player_ids'] != null
          ? List<String>.from(json['player_ids'] as List)
          : null,
      trainingTypeIds: json['training_type_ids'] != null
          ? List<String>.from(json['training_type_ids'] as List)
          : null,
      teamIds: json['team_ids'] != null
          ? List<String>.from(json['team_ids'] as List)
          : null,
    );
  }
}

