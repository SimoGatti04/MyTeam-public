import 'dart:io';
import 'package:flutter/material.dart';
import '../../../domain/entities/compression_settings.dart';
import '../screens/widgets/compression_settings_widget.dart';

/// Dialog per modificare i titoli e impostazioni di compressione di più file prima dell'upload
class MultiFileRenameDialog extends StatefulWidget {
  final List<File> files;
  final CompressionSettings compressionSettings;
  
  const MultiFileRenameDialog({
    super.key,
    required this.files,
    required this.compressionSettings,
  });
  
  @override
  State<MultiFileRenameDialog> createState() => _MultiFileRenameDialogState();
}

class _MultiFileRenameDialogState extends State<MultiFileRenameDialog> {
  late List<TextEditingController> _titleControllers;
  final Map<int, String> _originalTitles = {};
  late CompressionSettings _compressionSettings;
  
  @override
  void initState() {
    super.initState();
    _compressionSettings = widget.compressionSettings;
    _titleControllers = widget.files.asMap().entries.map((entry) {
      final index = entry.key;
      final file = entry.value;
      final fileName = file.path.split(Platform.pathSeparator).last;
      final titleWithoutExtension = fileName.replaceAll(RegExp(r'\.[^.]*$'), '');
      _originalTitles[index] = titleWithoutExtension;
      
      return TextEditingController(text: titleWithoutExtension);
    }).toList();
  }
  
  @override
  void dispose() {
    for (final controller in _titleControllers) {
      controller.dispose();
    }
    super.dispose();
  }
  
  Map<int, String> getModifiedTitles() {
    final modified = <int, String>{};
    for (int i = 0; i < _titleControllers.length; i++) {
      final title = _titleControllers[i].text.trim();
      if (title.isNotEmpty && title != _originalTitles[i]) {
        modified[i] = title;
      }
    }
    return modified;
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifica Titoli e Impostazioni'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.files.length} file selezionati',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 16),
              ...widget.files.asMap().entries.map((entry) {
                final index = entry.key;
                final file = entry.value;
                final fileName = file.path.split(Platform.pathSeparator).last;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _titleControllers[index],
                        decoration: const InputDecoration(
                          labelText: 'Titolo',
                          hintText: 'Inserisci titolo video',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        maxLength: 255,
                        textCapitalization: TextCapitalization.words,
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 32),
              const Text(
                'Impostazioni Compressione',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Le impostazioni verranno applicate a tutti i file',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              CompressionSettingsWidget(
                settings: _compressionSettings,
                onSettingsChanged: (settings) {
                  setState(() {
                    _compressionSettings = settings;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Annulla'),
        ),
        TextButton(
          onPressed: () {
            // Valida tutti i titoli
            bool allValid = true;
            for (int i = 0; i < _titleControllers.length; i++) {
              final title = _titleControllers[i].text.trim();
              if (title.isEmpty) {
                allValid = false;
                break;
              }
            }
            
            if (allValid) {
              final titles = <int, String>{};
              for (int i = 0; i < _titleControllers.length; i++) {
                final title = _titleControllers[i].text.trim();
                titles[i] = title.isEmpty ? _originalTitles[i]! : title;
              }
              // Ritorna sia i titoli che le impostazioni di compressione
              Navigator.of(context).pop({
                'titles': titles,
                'compressionSettings': _compressionSettings,
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tutti i titoli devono essere compilati'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: const Text('Conferma'),
        ),
      ],
    );
  }
}

