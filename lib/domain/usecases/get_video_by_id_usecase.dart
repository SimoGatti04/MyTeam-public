import '../entities/video.dart';
import '../repositories/video_repository.dart';

/// Use case per ottenere dettagli video per ID
class GetVideoByIdUseCase {
  final VideoRepository repository;
  
  GetVideoByIdUseCase(this.repository);
  
  /// Esegue il recupero del video per ID
  /// 
  /// Args:
  ///   videoId: ID del video (UUID)
  /// 
  /// Returns:
  ///   Video entity con dettagli completi
  /// 
  /// Throws:
  ///   Exception se video non trovato o errore di rete
  Future<Video> execute(String videoId) async {
    return await repository.getVideoById(videoId);
  }
}

