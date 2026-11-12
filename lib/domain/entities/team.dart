/// Team entity - Domain layer
class Team {
  final String id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? color; // Hex color
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int videoCount; // Numero video associati (calcolato)
  
  const Team({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    this.color,
    required this.createdAt,
    this.updatedAt,
    required this.videoCount,
  });
}

/// VideoTeam association entity
class VideoTeam {
  final String id;
  final String videoId;
  final String teamId;
  final Team? team; // Team details (opzionale)
  final DateTime taggedAt;
  
  const VideoTeam({
    required this.id,
    required this.videoId,
    required this.teamId,
    this.team,
    required this.taggedAt,
  });
}

