# Video List Implementation (App-Side)

## Strategia

- **Video List Screen** con lista scrollabile
- **Paginazione** automatica (infinite scroll)
- **Ricerca** in tempo reale
- **Sorting** configurabile
- **Thumbnail** lazy loading
- **Pull to refresh** per aggiornare lista

---

## Implementazione

### Domain Layer

#### Entity: Video

**File:** `lib/domain/entities/video.dart`

```dart
class Video {
  final String id;
  final String title;
  final String fileName;
  final int fileSize;
  final Duration? duration;
  final int? width;
  final int? height;
  final String? thumbnailUrl;
  final VideoStatus status;
  final DateTime createdAt;
  
  // Compression metadata
  final int? originalResolutionWidth;
  final int? originalResolutionHeight;
  final double? originalFramerate;
  final double? compressedFramerate;
  final int? originalFileSize;
  final double? compressionRatio;
  
  const Video({
    required this.id,
    required this.title,
    required this.fileName,
    required this.fileSize,
    this.duration,
    this.width,
    this.height,
    this.thumbnailUrl,
    required this.status,
    required this.createdAt,
    this.originalResolutionWidth,
    this.originalResolutionHeight,
    this.originalFramerate,
    this.compressedFramerate,
    this.originalFileSize,
    this.compressionRatio,
  });
}

enum VideoStatus {
  processing,
  ready,
  error,
  deleted,
}
```

#### Use Case: GetVideosUseCase

**File:** `lib/domain/usecases/get_videos_usecase.dart`

```dart
import '../repositories/video_repository.dart';
import '../entities/video.dart';

class GetVideosUseCase {
  final VideoRepository repository;
  
  GetVideosUseCase(this.repository);
  
  Future<List<Video>> execute({
    int page = 1,
    int limit = 20,
    String? search,
    String? sort,
    String? status,
  }) async {
    return await repository.getVideos(
      page: page,
      limit: limit,
      search: search,
      sort: sort,
      status: status,
    );
  }
}
```

#### Repository Interface: VideoRepository

**File:** `lib/domain/repositories/video_repository.dart`

```dart
import '../entities/video.dart';

abstract class VideoRepository {
  Future<List<Video>> getVideos({
    int page = 1,
    int limit = 20,
    String? search,
    String? sort,
    String? status,
  });
  
  Future<Video> getVideoById(String id);
}
```

---

### Data Layer

#### Model: VideoListResponse

**File:** `lib/data/models/video_list_response.dart`

```dart
import '../../domain/entities/video.dart';

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
  
  factory VideoListResponse.fromJson(Map<String, dynamic> json) {
    return VideoListResponse(
      items: (json['items'] as List)
          .map((item) => Video.fromJson(item))
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      limit: json['limit'] as int,
    );
  }
}
```

#### Data Source: VideoRemoteDataSource

**File:** `lib/data/datasources/remote/video_remote_datasource.dart`

```dart
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../models/video_list_response.dart';
import '../../models/video_response.dart';

class VideoRemoteDataSource {
  final ApiClient apiClient;
  
  VideoRemoteDataSource(this.apiClient);
  
  Future<VideoListResponse> getVideos({
    int page = 1,
    int limit = 20,
    String? search,
    String? sort,
    String? status,
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
    
    final response = await apiClient.dio.get(
      ApiConstants.videos,
      queryParameters: queryParams,
    );
    
    return VideoListResponse.fromJson(response.data);
  }
  
  Future<VideoResponse> getVideoById(String id) async {
    final response = await apiClient.dio.get(
      '${ApiConstants.videos}/$id',
    );
    
    return VideoResponse.fromJson(response.data);
  }
}
```

#### Repository Implementation: VideoRepositoryImpl

**File:** `lib/data/repositories/video_repository_impl.dart`

```dart
import '../../domain/entities/video.dart';
import '../../domain/repositories/video_repository.dart';
import '../datasources/remote/video_remote_datasource.dart';
import '../models/video_response.dart';

class VideoRepositoryImpl implements VideoRepository {
  final VideoRemoteDataSource remoteDataSource;
  
  VideoRepositoryImpl(this.remoteDataSource);
  
  @override
  Future<List<Video>> getVideos({
    int page = 1,
    int limit = 20,
    String? search,
    String? sort,
    String? status,
  }) async {
    final response = await remoteDataSource.getVideos(
      page: page,
      limit: limit,
      search: search,
      sort: sort,
      status: status,
    );
    
    return response.items;
  }
  
  @override
  Future<Video> getVideoById(String id) async {
    final response = await remoteDataSource.getVideoById(id);
    return response.toEntity();
  }
}
```

---

### Presentation Layer

#### ViewModel: VideoListViewModel

**File:** `lib/features/video/viewmodels/video_list_viewmodel.dart`

```dart
import 'package:flutter/foundation.dart';
import '../../../domain/entities/video.dart';
import '../../../domain/usecases/get_videos_usecase.dart';

class VideoListViewModel extends ChangeNotifier {
  final GetVideosUseCase getVideosUseCase;
  
  List<Video> _videos = [];
  bool _isLoading = false;
  String? _error;
  String? _searchQuery;
  String _sortOption = 'date_desc';
  int _currentPage = 1;
  int _total = 0;
  bool _hasMore = true;
  
  List<Video> get videos => _videos;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get searchQuery => _searchQuery;
  String get sortOption => _sortOption;
  bool get hasMore => _hasMore;
  
  VideoListViewModel(this.getVideosUseCase);
  
  Future<void> loadVideos({bool refresh = false}) async {
    if (_isLoading) return;
    
    if (refresh) {
      _currentPage = 1;
      _videos = [];
      _hasMore = true;
    }
    
    if (!_hasMore) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final newVideos = await getVideosUseCase.execute(
        page: _currentPage,
        limit: 20,
        search: _searchQuery,
        sort: _sortOption,
      );
      
      if (refresh) {
        _videos = newVideos;
      } else {
        _videos.addAll(newVideos);
      }
      
      _hasMore = newVideos.length == 20;
      _currentPage++;
      
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> search(String query) async {
    _searchQuery = query.isEmpty ? null : query;
    await loadVideos(refresh: true);
  }
  
  Future<void> setSortOption(String sort) async {
    _sortOption = sort;
    await loadVideos(refresh: true);
  }
  
  Future<void> refresh() async {
    await loadVideos(refresh: true);
  }
}
```

#### Screen: VideoListScreen

**File:** `lib/presentation/screens/video/video_list_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../features/video/viewmodels/video_list_viewmodel.dart';
import '../widgets/video_list_item.dart';
import '../widgets/video_search_bar.dart';
import '../widgets/video_sort_dialog.dart';

class VideoListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video'),
        actions: [
          IconButton(
            icon: Icon(Icons.sort),
            onPressed: () => _showSortDialog(context),
          ),
        ],
      ),
      body: Consumer<VideoListViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading && viewModel.videos.isEmpty) {
            return Center(child: CircularProgressIndicator());
          }
          
          if (viewModel.error != null && viewModel.videos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Errore: ${viewModel.error}'),
                  ElevatedButton(
                    onPressed: () => viewModel.refresh(),
                    child: Text('Riprova'),
                  ),
                ],
              ),
            );
          }
          
          return RefreshIndicator(
            onRefresh: () => viewModel.refresh(),
            child: Column(
              children: [
                VideoSearchBar(
                  onSearch: (query) => viewModel.search(query),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: viewModel.videos.length + (viewModel.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == viewModel.videos.length) {
                        // Load more
                        viewModel.loadVideos();
                        return Center(child: CircularProgressIndicator());
                      }
                      
                      return VideoListItem(
                        video: viewModel.videos[index],
                        onTap: () => _navigateToVideoDetail(context, viewModel.videos[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  void _showSortDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => VideoSortDialog(
        currentSort: Provider.of<VideoListViewModel>(context).sortOption,
        onSortSelected: (sort) {
          Provider.of<VideoListViewModel>(context).setSortOption(sort);
        },
      ),
    );
  }
  
  void _navigateToVideoDetail(BuildContext context, Video video) {
    // Navigate to video detail screen
  }
}
```

#### Widget: VideoListItem

**File:** `lib/presentation/screens/widgets/video_list_item.dart`

```dart
import 'package:flutter/material.dart';
import '../../../domain/entities/video.dart';

class VideoListItem extends StatelessWidget {
  final Video video;
  final VoidCallback onTap;
  
  VideoListItem({
    required this.video,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildThumbnail(),
      title: Text(video.title),
      subtitle: _buildSubtitle(),
      trailing: _buildTrailing(),
      onTap: onTap,
    );
  }
  
  Widget _buildThumbnail() {
    if (video.thumbnailUrl != null) {
      return Image.network(
        video.thumbnailUrl!,
        width: 80,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.video_library, size: 40);
        },
      );
    }
    return Icon(Icons.video_library, size: 40);
  }
  
  Widget _buildSubtitle() {
    final parts = <String>[];
    
    if (video.duration != null) {
      parts.add(_formatDuration(video.duration!));
    }
    
    if (video.width != null && video.height != null) {
      parts.add('${video.width}x${video.height}');
    }
    
    parts.add(_formatFileSize(video.fileSize));
    
    return Text(parts.join(' • '));
  }
  
  Widget _buildTrailing() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (video.status == VideoStatus.processing)
          CircularProgressIndicator(strokeWidth: 2),
        if (video.status == VideoStatus.error)
          Icon(Icons.error, color: Colors.red),
        Text(
          _formatDate(video.createdAt),
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
  
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Oggi';
    } else if (difference.inDays == 1) {
      return 'Ieri';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} giorni fa';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
```

---

## Configurazione

### API Constants

**File:** `lib/core/constants/api_constants.dart`

```dart
class ApiConstants {
  static const String videos = '${AppConstants.apiBaseUrl}/videos';
  
  static String videoDetail(String id) => '$videos/$id';
  static String videoThumbnail(String id) => '$videos/$id/thumbnail';
  static String videoDownload(String id) => '$videos/$id/download';
  static String videoStream(String id) => '$videos/$id/stream';
}
```

---

## Sorting Options

```dart
enum VideoSortOption {
  uploadedAtAsc('uploaded_at_asc', 'Data aggiunta (crescente)'),
  uploadedAtDesc('uploaded_at_desc', 'Data aggiunta (decrescente)'),
  recordedAtAsc('recorded_at_asc', 'Data realizzazione (crescente)'),
  recordedAtDesc('recorded_at_desc', 'Data realizzazione (decrescente)'),
  titleAsc('title_asc', 'Nome (A-Z)'),
  titleDesc('title_desc', 'Nome (Z-A)'),
  playerAsc('player_asc', 'Giocatore (A-Z)'),
  playerDesc('player_desc', 'Giocatore (Z-A)'),
  trainingTypeAsc('training_type_asc', 'Tipo allenamento (A-Z)'),
  trainingTypeDesc('training_type_desc', 'Tipo allenamento (Z-A)'),
  teamAsc('team_asc', 'Squadra (A-Z)'),
  teamDesc('team_desc', 'Squadra (Z-A)'),
  sizeAsc('size_asc', 'Dimensione (crescente)'),
  sizeDesc('size_desc', 'Dimensione (decrescente)');
  
  final String value;
  final String label;
  
  const VideoSortOption(this.value, this.label);
}
```

**Nota:** Per i dettagli completi su ordinamento e filtraggio, vedere [video-organization-system.md](../video-organization-system.md).

