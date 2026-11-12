import 'package:flutter/material.dart';

/// Upload progress widget
class UploadProgressWidget extends StatelessWidget {
  final double progress; // 0.0 - 1.0
  final String? statusMessage;
  
  const UploadProgressWidget({
    super.key,
    required this.progress,
    this.statusMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (statusMessage != null) ...[
              Text(
                statusMessage!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
            ],
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Text(
              '${(progress * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

