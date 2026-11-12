/// Upload task entity - Domain layer
class UploadTask {
  final String id;
  final String? videoId; // null se non ancora creato
  final String localFilePath;
  final String remoteFileName;
  final int totalBytes;
  final int uploadedBytes;
  final UploadStatus status;
  final double progress; // 0.0 - 1.0
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  
  const UploadTask({
    required this.id,
    this.videoId,
    required this.localFilePath,
    required this.remoteFileName,
    required this.totalBytes,
    required this.uploadedBytes,
    required this.status,
    required this.progress,
    this.errorMessage,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
  });
  
  UploadTask copyWith({
    String? id,
    String? videoId,
    String? localFilePath,
    String? remoteFileName,
    int? totalBytes,
    int? uploadedBytes,
    UploadStatus? status,
    double? progress,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return UploadTask(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      localFilePath: localFilePath ?? this.localFilePath,
      remoteFileName: remoteFileName ?? this.remoteFileName,
      totalBytes: totalBytes ?? this.totalBytes,
      uploadedBytes: uploadedBytes ?? this.uploadedBytes,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

enum UploadStatus {
  queued,      // In coda, in attesa di essere processato
  scanning,    // Scansione cartella in corso (solo per folder selection)
  compressing, // Compressione in corso
  uploading,   // Upload in corso
  completed,   // Completato con successo
  error,       // Errore durante processing
  cancelled,   // Cancellato dall'utente
}

