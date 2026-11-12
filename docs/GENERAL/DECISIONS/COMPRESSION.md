# Compressione Video Client-Side

## Strategia

**Compressione Client-Side** prima upload al server.

---

## Implementazione Client (Flutter)

### 1. Estrazione Metadata Originale

**Package:** `ffmpeg_kit_flutter_new`

```dart
// lib/core/services/video_metadata_service.dart
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'dart:convert';

class VideoMetadataService {
  static Future<Map<String, dynamic>> extractMetadata(String videoPath) async {
    final session = await FFprobeKit.execute(
      '-v quiet -print_format json -show_format -show_streams "$videoPath"',
    );
    
    final returnCode = await session.getReturnCode();
    if (returnCode?.isValueSuccess() ?? false) {
      final output = await session.getOutput();
      if (output != null) {
        final jsonData = json.decode(output) as Map<String, dynamic>;
        return _parseMetadata(jsonData);
      }
    }
    
    final failStackTrace = await session.getFailStackTrace();
    throw Exception('FFprobe failed: ${failStackTrace ?? "Unknown error"}');
  }
  
  static Map<String, dynamic> _parseMetadata(Map<String, dynamic> json) {
    final format = json['format'] as Map<String, dynamic>?;
    final streams = json['streams'] as List<dynamic>?;
    
    final videoStream = streams?.firstWhere(
      (s) => s['codec_type'] == 'video',
      orElse: () => null,
    ) as Map<String, dynamic>?;
    
    if (videoStream == null) {
      throw Exception('No video stream found');
    }
    
    return {
      'width': videoStream['width'] as int?,
      'height': videoStream['height'] as int?,
      'framerate': _parseFramerate(videoStream['r_frame_rate'] as String?),
      'duration': format?['duration'] != null 
        ? double.tryParse(format!['duration'] as String) 
        : null,
      'fileSize': format?['size'] != null 
        ? int.tryParse(format!['size'] as String) 
        : null,
      'codec': videoStream['codec_name'] as String?,
      'bitrate': format?['bit_rate'] != null 
        ? int.tryParse(format!['bit_rate'] as String) 
        : null,
    };
  }
  
  static double? _parseFramerate(String? rFrameRate) {
    if (rFrameRate == null) return null;
    final parts = rFrameRate.split('/');
    if (parts.length == 2) {
      final num = double.tryParse(parts[0]);
      final den = double.tryParse(parts[1]);
      if (num != null && den != null && den != 0) {
        return num / den;
      }
    }
    return null;
  }
}
```

### 2. Compressione Video

```dart
// lib/features/upload/services/video_compression_service.dart
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';

class VideoCompressionService {
  static Future<File> compressVideo({
    required File inputFile,
    required CompressionSettings settings,
  }) async {
    if (settings.keepOriginal) {
      return inputFile;
    }
    
    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.mp4';
    
    final command = _buildCompressionCommand(
      inputPath: inputFile.path,
      outputPath: outputPath,
      settings: settings,
    );
    
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    
    if (returnCode?.isValueSuccess() ?? false) {
      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        return outputFile;
      } else {
        throw Exception('Compressed file not created');
      }
    } else {
      final failStackTrace = await session.getFailStackTrace();
      throw Exception('FFmpeg compression failed: ${failStackTrace ?? "Unknown error"}');
    }
  }
  
  static String _buildCompressionCommand({
    required String inputPath,
    required String outputPath,
    required CompressionSettings settings,
  }) {
    final buffer = StringBuffer();
    
    buffer.write('-i "$inputPath"');
    buffer.write(' -c:v libx264');
    
    if (settings.resolutionWidth != null && settings.resolutionHeight != null) {
      buffer.write(' -vf scale=${settings.resolutionWidth}:${settings.resolutionHeight}');
    }
    
    if (settings.framerate != null) {
      buffer.write(' -r ${settings.framerate}');
    }
    
    buffer.write(' -preset ultrafast');
    buffer.write(' -c:a aac');
    buffer.write(' "$outputPath"');
    
    return buffer.toString();
  }
}
```

---

## Risoluzioni e Framerate Supportati

### Risoluzioni
- **480p** (SD) - 854x480
- **720p** (HD) - 1280x720
- **1080p** (Full HD) - 1920x1080
- **1440p** (2K) - 2560x1440
- **2160p** (4K UHD) - 3840x2160
- **Original** - Mantiene risoluzione originale

### Framerate
- **24 fps** - Cinema standard
- **30 fps** - TV standard
- **60 fps** - Smooth motion
- **120 fps** - High frame rate
- **Original** - Mantiene framerate originale

---

## Packages Necessari

### Flutter
```yaml
dependencies:
  ffmpeg_kit_flutter_new: ^2.0.0
  dio: ^5.0.0
  file_picker: ^5.0.0
```
