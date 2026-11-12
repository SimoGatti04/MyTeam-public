# Modelli Dati App Flutter

## Panoramica

Questi sono i modelli dati **interni all'app** (domain entities, local models).

---

## Domain Entities

### Video Entity

```dart
class Video {
  final String id;
  final String title;
  final String? description;
  final String fileName;
  final int fileSize; // bytes
  final String fileFormat; // mp4, avi, etc.
  final Duration? duration;
  final int? width;
  final int? height;
  final String? thumbnailUrl;
  final DateTime uploadedAt;
  final DateTime? lastModifiedAt;
  final VideoStatus status;
  final Map<String, dynamic>? metadata;
  
  // Compression metadata
  final int? originalResolutionWidth;
  final int? originalResolutionHeight;
  final double? originalFramerate;
  final double? compressedFramerate;
  final int? originalFileSize;
  final double? compressionRatio;
}
```

### UploadTask Entity

```dart
class UploadTask {
  final String id;
  final String? videoId;
  final String localFilePath;
  final String remoteFileName;
  final int totalBytes;
  final int uploadedBytes;
  final UploadStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? errorMessage;
  final double progress; // 0.0-1.0
}
```

### DownloadTask Entity

```dart
class DownloadTask {
  final String id;
  final String videoId;
  final String localSavePath;
  final int totalBytes;
  final int downloadedBytes;
  final DownloadStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? errorMessage;
  final double progress; // 0.0-1.0
}
```

### StreamingSession Entity

```dart
class StreamingSession {
  final String videoId;
  final String streamUrl;
  final Duration? currentPosition;
  final bool isPlaying;
}
```

---

## Data Models (DTOs)

### VideoResponse (API DTO)

```dart
class VideoResponse {
  final String id;
  final String title;
  final String? description;
  final String filename;
  final int fileSize;
  final String fileFormat;
  final int? duration;
  final int? width;
  final int? height;
  final String? thumbnailUrl;
  final String status;
  final Map<String, dynamic>? videoMetadata;
  final int? originalResolutionWidth;
  final int? originalResolutionHeight;
  final double? originalFramerate;
  final double? compressedFramerate;
  final int? originalFileSize;
  final double? compressionRatio;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  Video toEntity() {
    // Convert DTO to Domain Entity
  }
}
```

---

## Local Models

### CachedVideo (SQLite)

```dart
class CachedVideo {
  final String id;
  final String title;
  final String? description;
  final int fileSize;
  final int? duration;
  final DateTime cachedAt;
  final DateTime? lastSyncAt;
}
```

---

## Enums

### VideoStatus

```dart
enum VideoStatus {
  processing,
  ready,
  error,
  deleted
}
```

### UploadStatus

```dart
enum UploadStatus {
  pending,
  uploading,
  paused,
  completed,
  failed,
  cancelled
}
```

### DownloadStatus

```dart
enum DownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
  cancelled
}
```

---

**Nota:** App non ancora implementata. Questo documento sarà aggiornato durante lo sviluppo.

Per modelli dati per comunicazione API, vedere `GENERAL/DATA-MODELS.md`.

