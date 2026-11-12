# Visualizzazione Metadata Video Selezionato (Upload)

## Descrizione

Mostrare all'utente le informazioni del video originale selezionato e la dimensione prevista dopo compressione nella schermata upload, prima di procedere con l'upload.

---

## Requisiti

### Informazioni da Mostrare

1. **Metadata Video Originale** (dal file selezionato):
   - Risoluzione originale (width x height, es. "1920x1080")
   - FPS originali (es. "30.0 fps")
   - Dimensione file originale (già mostrata)

2. **Dimensione Prevista dopo Compressione**:
   - Calcolata in base a risoluzione e framerate scelti nelle impostazioni
   - Aggiornata dinamicamente quando l'utente cambia le impostazioni
   - Formattata in modo leggibile (es. "~45 MB")

---

## Implementazione

### 1. Estrazione Metadata alla Selezione Video

**File:** `lib/presentation/screens/upload/upload_screen.dart`

```dart
class _UploadScreenState extends State<UploadScreen> {
  File? _selectedVideo;
  Map<String, dynamic>? _videoMetadata; // Aggiunto
  
  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    
    if (result != null && result.files.single.path != null) {
      final videoFile = File(result.files.single.path!);
      
      // Estrai metadata
      try {
        final metadata = await VideoMetadataService.extractMetadata(videoFile.path);
        setState(() {
          _selectedVideo = videoFile;
          _videoMetadata = metadata;
        });
      } catch (e) {
        // Gestisci errore estrazione metadata
        setState(() {
          _selectedVideo = videoFile;
          _videoMetadata = null;
        });
      }
    }
  }
}
```

### 2. Calcolo Dimensione Prevista

**File:** `lib/features/upload/services/video_compression_service.dart`

Il metodo `estimateCompressedSize` esiste già ma deve essere migliorato per usare i metadata reali del video originale invece di assumere valori.

```dart
static Future<int> estimateCompressedSize({
  required File inputFile,
  required CompressionSettings settings,
  required Map<String, dynamic> originalMetadata, // Aggiunto
}) async {
  if (settings.keepOriginal) {
    return await inputFile.length();
  }
  
  // Usa metadata reali invece di assumere
  final originalWidth = originalMetadata['width'] as int?;
  final originalHeight = originalMetadata['height'] as int?;
  final originalFramerate = originalMetadata['framerate'] as double?;
  final originalSize = originalMetadata['file_size'] as int? ?? await inputFile.length();
  
  if (originalWidth == null || originalHeight == null) {
    // Fallback se metadata non disponibili
    return originalSize;
  }
  
  final originalArea = originalWidth * originalHeight;
  final targetArea = settings.resolutionWidth != null && settings.resolutionHeight != null
      ? settings.resolutionWidth! * settings.resolutionHeight!
      : originalArea;
  
  final areaRatio = targetArea / originalArea;
  
  // Calcola ratio framerate
  final targetFramerate = settings.framerate ?? originalFramerate ?? 30.0;
  final framerateRatio = originalFramerate != null && originalFramerate > 0
      ? targetFramerate / originalFramerate
      : 1.0;
  
  // Stima basata su area e framerate (fattore 0.8 per codec efficiency)
  final estimatedSize = (originalSize * areaRatio * framerateRatio * 0.8).round();
  
  return estimatedSize;
}
```

### 3. Widget per Visualizzazione Info

**File:** `lib/presentation/screens/widgets/video_info_widget.dart` (nuovo)

```dart
import 'package:flutter/material.dart';

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
```

### 4. Integrazione in UploadScreen

**File:** `lib/presentation/screens/upload/upload_screen.dart`

```dart
class _UploadScreenState extends State<UploadScreen> {
  File? _selectedVideo;
  Map<String, dynamic>? _videoMetadata;
  int? _estimatedCompressedSize;
  bool _isCalculatingSize = false;
  
  // ... existing code ...
  
  Future<void> _updateEstimatedSize() async {
    if (_selectedVideo == null || _videoMetadata == null) {
      return;
    }
    
    setState(() {
      _isCalculatingSize = true;
    });
    
    try {
      final estimatedSize = await VideoCompressionService.estimateCompressedSize(
        inputFile: _selectedVideo!,
        settings: _compressionSettings,
        originalMetadata: _videoMetadata!,
      );
      
      setState(() {
        _estimatedCompressedSize = estimatedSize;
        _isCalculatingSize = false;
      });
    } catch (e) {
      setState(() {
        _estimatedCompressedSize = null;
        _isCalculatingSize = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ... existing code ...
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildFileSelection(),
            
            // Video Info Widget (nuovo)
            if (_selectedVideo != null && _videoMetadata != null) ...[
              const SizedBox(height: 16),
              VideoInfoWidget(
                metadata: _videoMetadata,
                estimatedSize: _estimatedCompressedSize,
                isLoading: _isCalculatingSize,
              ),
            ],
            
            // Compression settings
            if (_selectedVideo != null) ...[
              CompressionSettingsWidget(
                settings: _compressionSettings,
                onSettingsChanged: (settings) {
                  setState(() {
                    _compressionSettings = settings;
                  });
                  // Ricalcola dimensione prevista
                  _updateEstimatedSize();
                },
              ),
            ],
            
            // ... rest of UI ...
          ],
        ),
      ),
    );
  }
}
```

---

## Flusso Completo

```
1. Utente seleziona video
   ↓
2. Estrai metadata con VideoMetadataService
   ↓
3. Mostra metadata originali (risoluzione, FPS)
   ↓
4. Calcola dimensione prevista con estimateCompressedSize
   ↓
5. Mostra dimensione prevista
   ↓
6. Utente cambia impostazioni compressione
   ↓
7. Ricalcola e aggiorna dimensione prevista
```

---

## Note Tecniche

- **Estrazione Metadata**: Usa `VideoMetadataService.extractMetadata()` che già esiste
- **Calcolo Dimensione**: Migliorare `estimateCompressedSize()` per usare metadata reali
- **Aggiornamento Dinamico**: Ricalcolare quando cambiano `CompressionSettings`
- **Gestione Errori**: Se estrazione metadata fallisce, mostrare solo info disponibili
- **Performance**: Calcolo dimensione prevista in background per non bloccare UI

---

## Packages Utilizzati

- `ffmpeg_kit_flutter_new`: Per estrazione metadata (già presente)
- Nessun nuovo package richiesto

