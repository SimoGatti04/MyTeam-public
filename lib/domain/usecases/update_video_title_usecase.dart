import '../entities/video.dart';
import '../repositories/video_repository.dart';

/// Use case per aggiornare il titolo di un video
class UpdateVideoTitleUseCase {
  final VideoRepository repository;
  
  UpdateVideoTitleUseCase(this.repository);
  
  /// Esegue l'aggiornamento del titolo video
  Future<Video> execute({
    required String videoId,
    required String newTitle,
  }) async {
    // Validazione client-side
    if (newTitle.trim().isEmpty) {
      throw Exception('Title cannot be empty');
    }
    
    if (newTitle.length > 255) {
      throw Exception('Title too long (max 255 characters)');
    }
    
    return await repository.updateVideoTitle(
      videoId: videoId,
      newTitle: newTitle.trim(),
    );
  }
}

