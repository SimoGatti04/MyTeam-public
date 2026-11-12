# Struttura Progetto App Flutter

## Struttura Directory

```
app/
├── lib/
│   ├── main.dart                 # Entry point
│   │
│   ├── core/                     # Core functionality
│   │   ├── constants/
│   │   │   ├── app_constants.dart
│   │   │   └── api_constants.dart
│   │   ├── network/
│   │   │   └── api_client.dart
│   │   └── services/
│   │       ├── connectivity_service.dart
│   │       └── video_metadata_service.dart
│   │
│   ├── domain/                   # Domain layer
│   │   ├── entities/
│   │   │   ├── video.dart
│   │   │   ├── upload_task.dart
│   │   │   ├── compression_settings.dart
│   │   │   ├── download_task.dart (future)
│   │   │   └── streaming_session.dart (future)
│   │   ├── repositories/
│   │   │   ├── upload_repository.dart
│   │   │   ├── video_repository.dart (future)
│   │   │   └── download_repository.dart (future)
│   │   └── usecases/
│   │       ├── upload_video_usecase.dart
│   │       ├── get_videos_usecase.dart (future)
│   │       ├── download_video_usecase.dart (future)
│   │       └── stream_video_usecase.dart (future)
│   │
│   ├── data/                      # Data layer
│   │   ├── models/
│   │   │   └── video_response.dart
│   │   ├── datasources/
│   │   │   └── remote/
│   │   │       └── upload_remote_datasource.dart
│   │   └── repositories/
│   │       └── upload_repository_impl.dart
│   │
│   ├── features/                   # Feature-specific code
│   │   ├── upload/
│   │   │   ├── services/
│   │   │   │   └── video_compression_service.dart
│   │   │   └── viewmodels/
│   │   │       └── upload_viewmodel.dart
│   │   ├── download/ (future)
│   │   ├── streaming/ (future)
│   │   └── video/ (future)
│   │
│   └── presentation/              # Presentation layer
│       ├── screens/
│       │   ├── home_screen.dart
│       │   ├── upload/
│       │   │   └── upload_screen.dart
│       │   ├── video/
│       │   │   └── video_list_screen.dart (placeholder)
│       │   └── widgets/
│       │       ├── compression_settings_widget.dart
│       │       └── upload_progress_widget.dart
│       │
│       └── shared/ (future utilities/widgets)
│
├── android/
├── windows/
├── pubspec.yaml
└── README.md
```

---

## Convenzioni

### Naming
- **File**: `snake_case.dart`
- **Classi**: `PascalCase`
- **Funzioni**: `camelCase`
- **Variabili**: `camelCase`

### Import Organization
```dart
// Dart core
import 'dart:io';

// Flutter
import 'package:flutter/material.dart';

// Third-party
import 'package:dio/dio.dart';
import 'package:video_player/video_player.dart';

// Local
import 'package:app/domain/entities/video.dart';
import 'package:app/data/repositories/video_repository_impl.dart';
```

---

## Stato Implementazione

### ✅ Implementato (Fase 1 - Upload)
- **Core**: Constants, API client, Connectivity service, Video metadata service
- **Domain**: Video entity, UploadTask entity, CompressionSettings entity, UploadRepository interface, UploadVideoUseCase
- **Data**: VideoResponse model, UploadRemoteDataSource, UploadRepositoryImpl
- **Features**: Video compression service (FFmpeg), Upload viewmodel
- **Presentation**: Upload screen, Compression settings widget, Upload progress widget

### 🔄 In Sviluppo / Future
- **Domain**: DownloadTask, StreamingSession entities, VideoRepository, DownloadRepository
- **Data**: VideoRemoteDataSource, DownloadRemoteDataSource
- **Features**: Download, Streaming, Video list
- **Presentation**: Video list screen, Video detail screen, Download/Streaming screens

Per struttura progetto generale, vedere `GENERAL/PROJECT-STRUCTURE.md`.

