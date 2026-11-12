# Struttura Progetto Generale

## Struttura Directory Proposta

```
MyTeam/
├── server/                         # Backend FastAPI
│   ├── app/
│   │   ├── main.py                 # Entry point FastAPI
│   │   ├── core/                    # Core functionality
│   │   ├── api/                     # API routes
│   │   ├── models/                  # Database models
│   │   ├── schemas/                 # Pydantic schemas
│   │   ├── services/                # Business logic
│   │   └── utils/                   # Utilities
│   ├── tests/                       # Test suite
│   ├── storage/                      # File storage
│   ├── requirements.txt             # Python dependencies
│   └── README.md                    # Server README
│
├── app/                             # Frontend Flutter (da implementare)
│   ├── lib/
│   ├── main.dart                 # Entry point dell'app
│   │
│   ├── core/                     # Core functionality (shared across features)
│   │   ├── constants/
│   │   │   ├── app_constants.dart
│   │   │   ├── api_constants.dart
│   │   │   └── storage_constants.dart
│   │   ├── error/
│   │   │   ├── exceptions.dart
│   │   │   ├── failures.dart
│   │   │   └── error_handler.dart
│   │   ├── network/
│   │   │   ├── api_client.dart
│   │   │   ├── interceptors.dart
│   │   │   └── network_info.dart
│   │   ├── utils/
│   │   │   ├── validators.dart
│   │   │   ├── formatters.dart
│   │   │   ├── file_utils.dart
│   │   │   └── date_utils.dart
│   │   ├── extensions/
│   │   │   ├── string_extensions.dart
│   │   │   ├── date_extensions.dart
│   │   │   └── context_extensions.dart
│   │   └── di/
│   │       └── injection_container.dart  # Dependency Injection setup
│   │
│   ├── domain/                   # Business logic layer (pure Dart)
│   │   ├── entities/            # Domain entities
│   │   │   ├── user.dart
│   │   │   ├── video.dart
│   │   │   ├── upload_task.dart
│   │   │   ├── download_task.dart
│   │   │   └── streaming_session.dart
│   │   ├── repositories/        # Repository interfaces
│   │   │   ├── auth_repository.dart
│   │   │   ├── video_repository.dart
│   │   │   ├── upload_repository.dart
│   │   │   ├── download_repository.dart
│   │   │   └── streaming_repository.dart
│   │   ├── usecases/            # Business logic use cases
│   │   │   ├── auth/
│   │   │   │   ├── login_usecase.dart
│   │   │   │   ├── logout_usecase.dart
│   │   │   │   └── refresh_token_usecase.dart
│   │   │   ├── video/
│   │   │   │   ├── get_videos_usecase.dart
│   │   │   │   ├── get_video_by_id_usecase.dart
│   │   │   │   ├── search_videos_usecase.dart
│   │   │   │   └── delete_video_usecase.dart
│   │   │   ├── upload/
│   │   │   │   ├── start_upload_usecase.dart
│   │   │   │   ├── pause_upload_usecase.dart
│   │   │   │   ├── resume_upload_usecase.dart
│   │   │   │   └── cancel_upload_usecase.dart
│   │   │   ├── download/
│   │   │   │   ├── start_download_usecase.dart
│   │   │   │   ├── pause_download_usecase.dart
│   │   │   │   ├── resume_download_usecase.dart
│   │   │   │   └── cancel_download_usecase.dart
│   │   │   └── streaming/
│   │   │       ├── get_stream_url_usecase.dart
│   │   │       └── save_watch_position_usecase.dart
│   │   └── errors/
│   │       └── domain_exceptions.dart
│   │
│   ├── data/                     # Data layer
│   │   ├── models/              # Data Transfer Objects (DTOs)
│   │   │   ├── video_response.dart
│   │   │   ├── user_response.dart
│   │   │   ├── auth_response.dart
│   │   │   ├── upload_init_response.dart
│   │   │   └── cached_video.dart
│   │   ├── datasources/         # Data sources implementations
│   │   │   ├── remote/
│   │   │   │   ├── auth_remote_datasource.dart
│   │   │   │   ├── video_remote_datasource.dart
│   │   │   │   ├── upload_remote_datasource.dart
│   │   │   │   └── download_remote_datasource.dart
│   │   │   └── local/
│   │   │       ├── auth_local_datasource.dart  # Secure storage
│   │   │       ├── video_local_datasource.dart  # SQLite cache
│   │   │       ├── settings_local_datasource.dart  # SharedPreferences
│   │   │       └── file_local_datasource.dart  # File system
│   │   ├── repositories/        # Repository implementations
│   │   │   ├── auth_repository_impl.dart
│   │   │   ├── video_repository_impl.dart
│   │   │   ├── upload_repository_impl.dart
│   │   │   ├── download_repository_impl.dart
│   │   │   └── streaming_repository_impl.dart
│   │   └── cache/
│   │       ├── video_cache_manager.dart
│   │       └── cache_helper.dart
│   │
│   ├── presentation/            # Presentation layer (UI)
│   │   ├── theme/
│   │   │   ├── app_theme.dart
│   │   │   ├── colors.dart
│   │   │   └── text_styles.dart
│   │   ├── routes/
│   │   │   ├── app_router.dart
│   │   │   └── route_names.dart
│   │   ├── providers/           # State management (se Provider)
│   │   │   ├── video_provider.dart
│   │   │   ├── upload_provider.dart
│   │   │   ├── download_provider.dart
│   │   │   ├── video_provider.dart
│   │   │   ├── player_provider.dart
│   │   │   ├── training_type_provider.dart
│   │   │   ├── team_provider.dart
│   │   │   ├── note_provider.dart
│   │   │   └── settings_provider.dart
│   │   ├── features/
│   │   │   ├── home/
│   │   │   │   ├── screens/
│   │   │   │   │   └── home_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── video_grid.dart
│   │   │   │       └── video_list_item.dart
│   │   │   ├── video/
│   │   │   │   ├── screens/
│   │   │   │   │   ├── video_list_screen.dart
│   │   │   │   │   ├── video_detail_screen.dart
│   │   │   │   │   └── video_search_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── video_card.dart
│   │   │   │       ├── video_metadata.dart
│   │   │   │       └── video_filter.dart
│   │   │   ├── upload/
│   │   │   │   ├── screens/
│   │   │   │   │   └── upload_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── upload_progress_item.dart
│   │   │   │       ├── file_picker_button.dart
│   │   │   │       └── upload_queue.dart
│   │   │   ├── download/
│   │   │   │   ├── screens/
│   │   │   │   │   └── download_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── download_progress_item.dart
│   │   │   │       └── download_queue.dart
│   │   │   ├── streaming/
│   │   │   │   ├── screens/
│   │   │   │   │   └── player_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── video_player_widget.dart
│   │   │   │       ├── player_controls.dart
│   │   │   │       └── quality_selector.dart
│   │   │   ├── organization/                    # Video organization (players, training types, teams, notes)
│   │   │   │   ├── screens/
│   │   │   │   │   ├── player_management_screen.dart
│   │   │   │   │   ├── training_type_management_screen.dart
│   │   │   │   │   ├── team_management_screen.dart
│   │   │   │   │   └── video_filter_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── player_chip.dart
│   │   │   │       ├── training_type_chip.dart
│   │   │   │       ├── team_chip.dart
│   │   │   │       └── date_filter_widget.dart
│   │   │   │   ├── screens/
│   │   │   │   │   └── person_management_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       └── person_card.dart
│   │   │   └── settings/
│   │   │       ├── screens/
│   │   │       │   └── settings_screen.dart
│   │   │       └── widgets/
│   │   │           ├── server_config_tile.dart
│   │   │           ├── storage_tile.dart
│   │   │           └── preferences_tile.dart
│   │   └── widgets/             # Shared UI widgets
│   │       ├── loading_indicator.dart
│   │       ├── error_widget.dart
│   │       ├── empty_state.dart
│   │       └── custom_app_bar.dart
│   │
│   └── shared/                  # Shared utilities (opzionale, può essere in core)
│       └── utils/
│           └── platform_utils.dart
│
│   ├── test/                     # Unit tests (Flutter)
│   ├── integration_test/         # Integration tests (Flutter)
│   ├── android/                  # Android specific
│   ├── windows/                  # Windows specific
│   ├── pubspec.yaml              # Flutter dependencies
│   └── README.md                 # App README
│
├── docs/                         # Documentazione (questa cartella)
│   ├── 01-REQUIREMENTS.md
│   ├── 02-ARCHITECTURE.md
│   ├── 03-DATA-MODELS.md
│   ├── 04-PROJECT-STRUCTURE.md
│   └── 05-TECHNICAL-DECISIONS.md
│
├── assets/                      # Assets (immagini, font, etc.)
│   ├── images/
│   ├── icons/
│   └── fonts/
│
├── pubspec.yaml                 # Flutter dependencies
├── analysis_options.yaml        # Linter rules
├── README.md
└── .gitignore
```

## Organizzazione per Feature

Ogni feature nel `presentation/features/` è organizzata con:

1. **Screens**: Schermate principali della feature
2. **Widgets**: Widget specifici riutilizzabili per quella feature
3. **Providers/State**: State management specifico (se non global)

## Separazione delle Responsabilità

- **Domain**: Logica di business pura, indipendente da Flutter
- **Data**: Implementazioni concrete, dipende da Domain
- **Presentation**: UI e state management, dipende da Domain
- **Core**: Utilità condivise, configurazioni globali

## Convenzioni di Nomenclatura

- **Files**: `snake_case.dart`
- **Classes**: `PascalCase`
- **Variables/Functions**: `camelCase`
- **Constants**: `SCREAMING_SNAKE_CASE`
- **Private members**: `_leadingUnderscore`

## Struttura File Tipica

### Entity Example
```dart
// lib/domain/entities/video.dart
class Video {
  final String id;
  final String title;
  // ...
}
```

### Use Case Example
```dart
// lib/domain/usecases/video/get_videos_usecase.dart
class GetVideosUseCase {
  final VideoRepository repository;
  
  GetVideosUseCase(this.repository);
  
  Future<Either<Failure, List<Video>>> call() {
    return repository.getVideos();
  }
}
```

### Repository Interface Example
```dart
// lib/domain/repositories/video_repository.dart
abstract class VideoRepository {
  Future<Either<Failure, List<Video>>> getVideos();
  Future<Either<Failure, Video>> getVideoById(String id);
  // ...
}
```

### Repository Implementation Example
```dart
// lib/data/repositories/video_repository_impl.dart
class VideoRepositoryImpl implements VideoRepository {
  final VideoRemoteDataSource remoteDataSource;
  final VideoLocalDataSource localDataSource;
  final NetworkInfo networkInfo;
  
  // Implementation...
}
```

### Screen Example
```dart
// lib/presentation/features/video/screens/video_list_screen.dart
class VideoListScreen extends StatelessWidget {
  // UI implementation
}
```

