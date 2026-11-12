import 'package:flutter/foundation.dart';
import '../../../domain/entities/video.dart';
import '../../../domain/usecases/get_video_by_id_usecase.dart';
import '../../../domain/usecases/update_video_title_usecase.dart';

/// ViewModel per Video Detail Screen
class VideoDetailViewModel extends ChangeNotifier {
  final GetVideoByIdUseCase getVideoByIdUseCase;
  final UpdateVideoTitleUseCase? updateVideoTitleUseCase;
  
  VideoDetailViewModel(
    this.getVideoByIdUseCase, {
    this.updateVideoTitleUseCase,
  });
  
  // State
  Video? _video;
  bool _isLoading = false;
  bool _isUpdating = false;
  String? _error;
  
  // Getters
  Video? get video => _video;
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get error => _error;
  bool get hasError => _error != null;
  
  /// Carica dettagli video per ID
  Future<void> loadVideo(String videoId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _video = await getVideoByIdUseCase.execute(videoId);
      _error = null;
    } catch (e) {
      _error = 'Failed to load video: $e';
      _video = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Refresh video details
  Future<void> refresh() async {
    if (_video != null) {
      await loadVideo(_video!.id);
    }
  }
  
  /// Update video title
  Future<bool> updateTitle(String newTitle) async {
    if (_video == null || updateVideoTitleUseCase == null) {
      return false;
    }
    
    _isUpdating = true;
    _error = null;
    notifyListeners();
    
    try {
      final updatedVideo = await updateVideoTitleUseCase!.execute(
        videoId: _video!.id,
        newTitle: newTitle,
      );
      
      _video = updatedVideo;
      _error = null;
      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update title: $e';
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }
}

