import 'package:flutter/material.dart';
import '../../../domain/entities/compression_settings.dart';

/// Compression settings widget
class CompressionSettingsWidget extends StatefulWidget {
  final CompressionSettings settings;
  final Function(CompressionSettings) onSettingsChanged;
  
  const CompressionSettingsWidget({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<CompressionSettingsWidget> createState() => _CompressionSettingsWidgetState();
}

class _CompressionSettingsWidgetState extends State<CompressionSettingsWidget> {
  late CompressionSettings _currentSettings;
  String? _selectedResolution;
  double? _selectedFramerate;
  
  @override
  void initState() {
    super.initState();
    _currentSettings = widget.settings;
    _selectedResolution = _currentSettings.keepOriginal ? 'Original' : null;
    _selectedFramerate = _currentSettings.framerate;
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Compression Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Resolution selector
            const Text('Resolution:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedResolution,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Select resolution',
              ),
              items: CompressionSettings.getResolutionNames().map((name) {
                return DropdownMenuItem(
                  value: name,
                  child: Text(name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedResolution = value;
                  if (value == 'Original') {
                    _currentSettings = const CompressionSettings(keepOriginal: true);
                  } else {
                    _currentSettings = CompressionSettings.fromResolutionName(value!);
                    _currentSettings = CompressionSettings(
                      resolutionWidth: _currentSettings.resolutionWidth,
                      resolutionHeight: _currentSettings.resolutionHeight,
                      framerate: _selectedFramerate,
                      keepOriginal: false,
                    );
                  }
                  widget.onSettingsChanged(_currentSettings);
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Framerate selector (only if not Original)
            if (!_currentSettings.keepOriginal) ...[
              const Text('Framerate:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<double>(
                value: _selectedFramerate,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Select framerate',
                ),
                items: [
                  ...CompressionSettings.getStandardFramerates().map((fps) {
                    return DropdownMenuItem(
                      value: fps,
                      child: Text('${fps.toStringAsFixed(0)} fps'),
                    );
                  }),
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Original'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedFramerate = value;
                    _currentSettings = CompressionSettings(
                      resolutionWidth: _currentSettings.resolutionWidth,
                      resolutionHeight: _currentSettings.resolutionHeight,
                      framerate: value,
                      keepOriginal: false,
                    );
                    widget.onSettingsChanged(_currentSettings);
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

