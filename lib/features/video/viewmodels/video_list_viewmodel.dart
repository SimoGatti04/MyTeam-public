import 'package:flutter/foundation.dart';
import '../../../domain/entities/video.dart';
import '../../../domain/usecases/get_videos_usecase.dart';

/// Video list view model - Presentation layer
class VideoListViewModel extends ChangeNotifier {
  final GetVideosUseCase getVideosUseCase;
  
  VideoListViewModel(this.getVideosUseCase);
  
  // State
  List<Video> _videos = [];
  bool _isLoading = false;
  String? _error;
  String? _searchQuery;
  String _sortOption = 'date_desc';
  int _currentPage = 1;
  int _total = 0;
  bool _hasMore = true;
  
  // Filters
  List<String>? _playerIds;
  List<String>? _trainingTypeIds;
  List<String>? _teamIds;
  DateTime? _recordedDateFrom;
  DateTime? _recordedDateTo;
  
  List<Video> get videos => _videos;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get searchQuery => _searchQuery;
  String get sortOption => _sortOption;
  bool get hasMore => _hasMore;
  int get total => _total;
  
  // Filter getters
  List<String>? get playerIds => _playerIds;
  List<String>? get trainingTypeIds => _trainingTypeIds;
  List<String>? get teamIds => _teamIds;
  DateTime? get recordedDateFrom => _recordedDateFrom;
  DateTime? get recordedDateTo => _recordedDateTo;
  
  /// Load videos with pagination
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
        playerIds: _playerIds,
        trainingTypeIds: _trainingTypeIds,
        teamIds: _teamIds,
        recordedDateFrom: _recordedDateFrom,
        recordedDateTo: _recordedDateTo,
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
  
  /// Search videos
  Future<void> search(String query) async {
    _searchQuery = query.isEmpty ? null : query;
    await loadVideos(refresh: true);
  }
  
  /// Set sort option
  Future<void> setSortOption(String sort) async {
    _sortOption = sort;
    await loadVideos(refresh: true);
  }
  
  /// Refresh videos
  Future<void> refresh() async {
    await loadVideos(refresh: true);
  }
  
  /// Set filters
  Future<void> setFilters({
    List<String>? playerIds,
    List<String>? trainingTypeIds,
    List<String>? teamIds,
    DateTime? recordedDateFrom,
    DateTime? recordedDateTo,
  }) async {
    _playerIds = playerIds?.isEmpty == true ? null : playerIds;
    _trainingTypeIds = trainingTypeIds?.isEmpty == true ? null : trainingTypeIds;
    _teamIds = teamIds?.isEmpty == true ? null : teamIds;
    _recordedDateFrom = recordedDateFrom;
    _recordedDateTo = recordedDateTo;
    await loadVideos(refresh: true);
  }
  
  /// Clear all filters
  Future<void> clearFilters() async {
    _playerIds = null;
    _trainingTypeIds = null;
    _teamIds = null;
    _recordedDateFrom = null;
    _recordedDateTo = null;
    await loadVideos(refresh: true);
  }
}

