import 'package:flutter/material.dart';
import '../../domain/entities/video.dart';

/// Video list item widget - Presentation layer
class VideoListItem extends StatelessWidget {
  final Video video;
  final VoidCallback onTap;
  
  const VideoListItem({
    super.key,
    required this.video,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildThumbnail(),
      title: Text(video.title),
      subtitle: _buildSubtitle(),
      trailing: _buildTrailing(),
      onTap: onTap,
    );
  }
  
  Widget _buildThumbnail() {
    if (video.thumbnailUrl != null) {
      return Image.network(
        video.thumbnailUrl!,
        width: 80,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.video_library, size: 40);
        },
      );
    }
    return const Icon(Icons.video_library, size: 40);
  }
  
  Widget _buildSubtitle() {
    final parts = <String>[];
    
    if (video.duration != null) {
      parts.add(_formatDuration(video.duration!));
    }
    
    if (video.width != null && video.height != null) {
      parts.add('${video.width}x${video.height}');
    }
    
    parts.add(_formatFileSize(video.fileSize));
    
    return Text(parts.join(' • '));
  }
  
  Widget _buildTrailing() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (video.status == VideoStatus.processing)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        if (video.status == VideoStatus.error)
          const Icon(Icons.error, color: Colors.red, size: 20),
        Text(
          _formatDate(video.uploadedAt),
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
  
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Oggi';
    } else if (difference.inDays == 1) {
      return 'Ieri';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} giorni fa';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

