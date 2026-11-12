import 'package:flutter/material.dart';

/// Widget per visualizzare informazioni video selezionato
class VideoInfoWidget extends StatelessWidget {
  final Map<String, dynamic>? metadata;
  final int? estimatedSize;
  final bool isLoading;
  
  const VideoInfoWidget({
    super.key,
    required this.metadata,
    this.estimatedSize,
    this.isLoading = false,
  });
  
  @override
  Widget build(BuildContext context) {
    if (metadata == null) {
      return const SizedBox.shrink();
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Video Info',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Risoluzione originale
            if (metadata!['width'] != null && metadata!['height'] != null)
              _buildInfoRow(
                'Risoluzione originale:',
                '${metadata!['width']}x${metadata!['height']}',
              ),
            
            // FPS originali
            if (metadata!['framerate'] != null)
              _buildInfoRow(
                'FPS originali:',
                '${(metadata!['framerate'] as double).toStringAsFixed(1)} fps',
              ),
            
            // Dimensione prevista
            if (estimatedSize != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                'Dimensione prevista:',
                _formatFileSize(estimatedSize!),
                isEstimated: true,
              ),
            ] else if (isLoading) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Text('Dimensione prevista: '),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value, {bool isEstimated = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              isEstimated ? '~$value' : value,
              style: TextStyle(
                fontWeight: isEstimated ? FontWeight.bold : FontWeight.normal,
                color: isEstimated ? Colors.blue[700] : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

