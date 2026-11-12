# Compression Flow (Client-Side)

## Strategia

- **Retry automatico** max 5 tentativi se compressione fallisce
- **Cleanup file compresso** dopo upload successo
- **Mai eliminare file originale** (solo copie/compressioni)
- **Utente può annullare** compressione e upload

---

## Retry Compressione

```dart
// lib/features/upload/services/video_compression_service.dart
class VideoCompressionService {
  static const int MAX_RETRIES = 5;
  
  Future<File> compressVideoWithRetry({
    required File inputFile,
    required CompressionSettings settings,
    required Function(int attempt, String? error) onRetry,
    required Function(String finalError) onFinalError,
  }) async {
    final errorLog = <String>[];
    
    for (int attempt = 1; attempt <= MAX_RETRIES; attempt++) {
      try {
        final compressedFile = await compressVideo(
          inputFile: inputFile,
          settings: settings,
        );
        return compressedFile;
      } catch (e) {
        final error = e.toString();
        errorLog.add('Attempt $attempt: $error');
        
        if (attempt < MAX_RETRIES) {
          onRetry(attempt, error);
          await Future.delayed(Duration(seconds: 1 << attempt));
        } else {
          onFinalError(errorLog.join('\n'));
          rethrow;
        }
      }
    }
    
    throw Exception('Compression failed after $MAX_RETRIES attempts');
  }
}
```

---

## Storage Management File Compresso

**File compresso temporaneo:**
- Cache directory app (`getTemporaryDirectory()`)
- Path: `{cache_dir}/compressed_{timestamp}.mp4`

**Cleanup:**
- ✅ Dopo upload successo (rimuovi file compresso)
- ✅ Dopo cancellazione compressione (utente annulla)
- ❌ Mai eliminare file originale

```dart
// lib/features/upload/services/compression_storage_service.dart
class CompressionStorageService {
  static Future<void> cleanupCompressedFile(String videoId) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/compressed_$videoId.mp4');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
```

---

## Cancellazione Compressione/Upload

```dart
// lib/features/upload/services/video_compression_service.dart
class VideoCompressionService {
  Process? _compressionProcess;
  bool _isCancelled = false;
  
  Future<File?> compressVideo({
    required File inputFile,
    required CompressionSettings settings,
    CancellationToken? cancellationToken,
  }) async {
    _isCancelled = false;
    
    final command = _buildCompressionCommand(
      inputPath: inputFile.path,
      outputPath: outputPath,
      settings: settings,
    );
    
    _compressionProcess = await Process.start('ffmpeg', command.split(' '));
    
    cancellationToken?.onCancel = () {
      _isCancelled = true;
      _compressionProcess?.kill();
      cleanupCompressedFile(outputPath);
    };
    
    final exitCode = await _compressionProcess!.exitCode;
    
    if (_isCancelled) {
      return null;
    }
    
    if (exitCode != 0) {
      throw CompressionException('Compression failed');
    }
    
    return File(outputPath);
  }
  
  void cancelCompression() {
    _isCancelled = true;
    _compressionProcess?.kill();
  }
}
```
