/// Player entity - Domain layer
class Player {
  final String id;
  final String name;
  final String? description;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int videoCount; // Numero video associati (calcolato)
  
  const Player({
    required this.id,
    required this.name,
    this.description,
    this.photoUrl,
    required this.createdAt,
    this.updatedAt,
    required this.videoCount,
  });
}

/// VideoPlayer association entity
class VideoPlayer {
  final String id;
  final String videoId;
  final String playerId;
  final Player? player; // Player details (opzionale)
  final DateTime taggedAt;
  
  const VideoPlayer({
    required this.id,
    required this.videoId,
    required this.playerId,
    this.player,
    required this.taggedAt,
  });
}

