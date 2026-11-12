/// Video entity - Domain layer
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
  final DateTime? recordedAt; // Data di realizzazione (modificabile)
  final DateTime? lastModifiedAt;
  final VideoStatus status;
  final Map<String, dynamic>? metadata; // codec, bitrate, etc.
  
  // Compression metadata (client-side compression)
  final int? originalResolutionWidth;  // Risoluzione originale prima compressione
  final int? originalResolutionHeight;
  final double? originalFramerate;  // Framerate originale prima compressione
  final double? compressedFramerate;  // Framerate compresso scelto dall'utente
  final int? originalFileSize;  // Dimensione originale prima compressione (bytes)
  final double? compressionRatio;  // Risparmio % (0.0-1.0, es: 0.75 = 75% risparmio)
  
  // Relazioni con Player, TrainingType, Team, Note
  final List<String>? playerIds; // Riferimenti a giocatori taggati
  final List<String>? trainingTypeIds; // Riferimenti a tipi di allenamento/esercizi
  final List<String>? teamIds; // Riferimenti a squadre taggate
  final List<String>? noteIds; // Riferimenti a note associate
  
  const Video({
    required this.id,
    required this.title,
    this.description,
    required this.fileName,
    required this.fileSize,
    required this.fileFormat,
    this.duration,
    this.width,
    this.height,
    this.thumbnailUrl,
    required this.uploadedAt,
    this.recordedAt,
    this.lastModifiedAt,
    required this.status,
    this.metadata,
    this.originalResolutionWidth,
    this.originalResolutionHeight,
    this.originalFramerate,
    this.compressedFramerate,
    this.originalFileSize,
    this.compressionRatio,
    this.playerIds,
    this.trainingTypeIds,
    this.teamIds,
    this.noteIds,
  });
}

enum VideoStatus {
  processing,
  ready,
  error,
  deleted,
}

