import '../../domain/entities/video.dart' show Video, VideoStatus;

/// Video list response model - Data layer (DTO from server)
class VideoListResponse {
  final List<Video> items;
  final int total;
  final int page;
  final int limit;
  
  VideoListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });
  
  /// Create from JSON
  factory VideoListResponse.fromJson(Map<String, dynamic> json) {
    return VideoListResponse(
      items: (json['items'] as List)
          .map((item) => VideoListItem.fromJson(item).toEntity())
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      limit: json['limit'] as int,
    );
  }
}

/// Video list item model - Data layer (lightweight DTO from server)
class VideoListItem {
  final String id;
  final String title;
  final String filename;
  final int fileSize;
  final int? duration; // seconds
  final int? width;
  final int? height;
  final String? thumbnailUrl;
  final String status; // processing, ready, error
  final DateTime createdAt;
  
  VideoListItem({
    required this.id,
    required this.title,
    required this.filename,
    required this.fileSize,
    this.duration,
    this.width,
    this.height,
    this.thumbnailUrl,
    required this.status,
    required this.createdAt,
  });
  
  /// Convert to domain entity
  Video toEntity() {
    return Video(
      id: id,
      title: title,
      fileName: filename,
      fileSize: fileSize,
      fileFormat: filename.split('.').last,
      duration: duration != null ? Duration(seconds: duration!) : null,
      width: width,
      height: height,
      thumbnailUrl: thumbnailUrl,
      uploadedAt: createdAt,
      status: _parseStatus(status),
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
  factory VideoListItem.fromJson(Map<String, dynamic> json) {
    return VideoListItem(
      id: json['id'] as String,
      title: json['title'] as String,
      filename: json['filename'] as String,
      fileSize: json['file_size'] as int,
      duration: json['duration'] as int?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

