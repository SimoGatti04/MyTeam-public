/// Note entity - Domain layer
class Note {
  final String id;
  final String videoId;
  final String content;
  final int? timestamp; // Secondi nel video (opzionale)
  final bool isPrivate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  const Note({
    required this.id,
    required this.videoId,
    required this.content,
    this.timestamp,
    required this.isPrivate,
    required this.createdAt,
    this.updatedAt,
  });
}

