/// TrainingType entity - Domain layer
class TrainingType {
  final String id;
  final String name;
  final String? description;
  final String? category; // "Riscaldamento", "Esercizio", "Partita"
  final String? color; // Hex color
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int videoCount; // Numero video associati (calcolato)
  
  const TrainingType({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.color,
    required this.createdAt,
    this.updatedAt,
    required this.videoCount,
  });
}

/// VideoTrainingType association entity
class VideoTrainingType {
  final String id;
  final String videoId;
  final String trainingTypeId;
  final TrainingType? trainingType; // TrainingType details (opzionale)
  final DateTime taggedAt;
  
  const VideoTrainingType({
    required this.id,
    required this.videoId,
    required this.trainingTypeId,
    this.trainingType,
    required this.taggedAt,
  });
}

