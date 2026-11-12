import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/utils/folder_scanner.dart';
import '../../../core/constants/app_constants.dart';

/// Dialog per mostrare progress durante scansione cartella
class FolderScanDialog extends StatefulWidget {
  final String folderPath;
  final Function(List<File>) onComplete;
  final VoidCallback onCancel;
  
  const FolderScanDialog({
    required this.folderPath,
    required this.onComplete,
    required this.onCancel,
  });
  
  @override
  State<FolderScanDialog> createState() => _FolderScanDialogState();
}

class _FolderScanDialogState extends State<FolderScanDialog> {
  int _filesFound = 0;
  String? _currentPath;
  bool _isScanning = true;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _startScanning();
  }
  
  Future<void> _startScanning() async {
    try {
      final validFiles = await FolderScanner.scanFolderForVideos(
        folderPath: widget.folderPath,
        maxDepth: AppConstants.maxFolderDepth,
        onProgress: (found, current) {
          if (mounted) {
            setState(() {
              _filesFound = found;
              _currentPath = current;
            });
          }
        },
      );
      
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        widget.onComplete(validFiles);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _error = e.toString();
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Scanning Folder'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isScanning) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Files found: $_filesFound'),
            if (_currentPath != null) ...[
              const SizedBox(height: 8),
              Text(
                _currentPath!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ] else if (_error != null) ...[
            Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error: $_error',
              style: const TextStyle(color: Colors.red),
            ),
          ] else ...[
            Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            Text('Found $_filesFound video files'),
          ],
        ],
      ),
      actions: [
        if (_isScanning)
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('Cancel'),
          )
        else
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
      ],
    );
  }
}

