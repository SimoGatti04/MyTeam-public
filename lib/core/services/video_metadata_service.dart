import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';
import '../../features/upload/services/video_compression_service.dart';
import 'debug_logger.dart';

/// Video metadata service - Core layer
class VideoMetadataService {
  /// Extract video metadata using FFprobe
  /// Gestisce path Windows e file OneDrive con normalizzazione path
  static Future<Map<String, dynamic>> extractMetadata(String videoPath) async {
    try {
      // Normalizza path per Windows e file OneDrive
      // Rimuovi spazi e caratteri speciali problematici
      String normalizedPath = videoPath;
      
      // Windows: gestisci path con spazi e caratteri speciali
      if (Platform.isWindows) {
        // Windows richiede path tra virgolette se contiene spazi
        // Ma FFprobeKit gestisce già le virgolette, quindi normalizziamo solo se necessario
        normalizedPath = videoPath.replaceAll('\\', '/'); // Normalizza separatori
      }
      
      // Verifica che il file esista e sia leggibile
      final file = File(normalizedPath);
      if (!await file.exists()) {
        throw Exception('File non trovato: $normalizedPath');
      }
      
      // Verifica permessi di lettura
      try {
        await file.readAsBytes().timeout(const Duration(seconds: 5), onTimeout: () {
          throw Exception('Timeout lettura file - possibile problema permessi');
        });
      } catch (e) {
        DebugLogger.warning('⚠️ [Metadata] Errore lettura file: $e');
        DebugLogger.debug('   Path: $normalizedPath');
        // Non bloccare, ma logga il warning
      }
      
      // Windows: usa FFprobe tramite Process.run (ffmpeg_kit_flutter_new potrebbe non supportare Windows)
      if (Platform.isWindows) {
        return await _extractMetadataWindows(normalizedPath);
      }
      
      // Altre piattaforme: usa FFprobeKit
      // Esegui FFprobe con path normalizzato
      // Usa path tra virgolette per gestire spazi e caratteri speciali
      final command = '-v quiet -print_format json -show_format -show_streams "${normalizedPath}"';
      
      DebugLogger.debug('🔍 [Metadata] Esecuzione FFprobe: $command');
      
      final session = await FFprobeKit.execute(command);
      
      final returnCode = await session.getReturnCode();
      if (returnCode?.isValueSuccess() ?? false) {
        final output = await session.getOutput();
        if (output != null && output.isNotEmpty) {
          final jsonData = json.decode(output) as Map<String, dynamic>;
          return _parseMetadata(jsonData);
        } else {
          throw Exception('FFprobe output vuoto - possibile problema con il file');
        }
      }
      
      final failStackTrace = await session.getFailStackTrace();
      final output = await session.getOutput();
      
      DebugLogger.error('❌ [Metadata] FFprobe fallito');
      DebugLogger.debug('   Return code: ${returnCode?.getValue()}');
      DebugLogger.debug('   Error: ${failStackTrace ?? "Unknown"}');
      DebugLogger.debug('   Output: ${output ?? "Empty"}');
      DebugLogger.debug('   Path: $normalizedPath');
      
      throw Exception('FFprobe failed: ${failStackTrace ?? "Unknown error"}');
    } catch (e) {
      DebugLogger.error('❌ [Metadata] Estrazione metadata fallita: $e');
      DebugLogger.debug('   Path originale: $videoPath');
      rethrow;
    }
  }
  
  static Map<String, dynamic> _parseMetadata(Map<String, dynamic> json) {
    final format = json['format'] as Map<String, dynamic>?;
    final streams = json['streams'] as List<dynamic>?;
    
    // Find video stream
    final videoStream = streams?.firstWhere(
      (stream) => (stream as Map<String, dynamic>)['codec_type'] == 'video',
      orElse: () => null,
    ) as Map<String, dynamic>?;
    
    if (videoStream == null) {
      throw Exception('No video stream found');
    }
    
    // Parse duration
    final durationStr = format?['duration'] as String?;
    final duration = durationStr != null ? double.parse(durationStr).round() : null;
    
    // Parse resolution
    final width = videoStream['width'] as int?;
    final height = videoStream['height'] as int?;
    
    // Parse framerate
    final framerateStr = videoStream['r_frame_rate'] as String?;
    double? framerate;
    if (framerateStr != null && framerateStr.contains('/')) {
      final parts = framerateStr.split('/');
      if (parts.length == 2) {
        final num = double.tryParse(parts[0]);
        final den = double.tryParse(parts[1]);
        if (num != null && den != null && den != 0) {
          framerate = num / den;
        }
      }
    }
    
    // Parse codec
    final codec = videoStream['codec_name'] as String?;
    
    // Parse bitrate
    final bitrateStr = format?['bit_rate'] as String?;
    final bitrate = bitrateStr != null ? int.tryParse(bitrateStr) : null;
    
    // Calcola numero totale di frame
    // Prova prima con nb_frames (numero reale di frame nel video)
    int? totalFrames;
    if (videoStream['nb_frames'] != null) {
      try {
        totalFrames = int.tryParse(videoStream['nb_frames'].toString());
      } catch (e) {
        // Ignora errore di parsing
      }
    }
    
    // Fallback: duration * framerate se nb_frames non disponibile
    if (totalFrames == null && duration != null && framerate != null) {
      totalFrames = (duration * framerate).round();
    }
    
    return {
      'duration': duration,
      'width': width,
      'height': height,
      'framerate': framerate,
      'codec': codec,
      'bitrate': bitrate,
      'file_size': format?['size'] != null ? int.tryParse(format!['size'] as String) : null,
      'total_frames': totalFrames,
    };
  }
  
  /// Estrazione metadati su Windows usando FFprobe tramite Process.run
  static Future<Map<String, dynamic>> _extractMetadataWindows(String videoPath) async {
    // Verifica che FFprobe sia disponibile
    try {
      final ffprobeCheck = await Process.run('ffprobe', ['-version']);
      if (ffprobeCheck.exitCode != 0) {
        throw FFmpegNotInstalledException();
      }
    } catch (e) {
      // Se è già FFmpegNotInstalledException, rilancia
      if (e is FFmpegNotInstalledException) {
        rethrow;
      }
      // Altrimenti, lancia FFmpegNotInstalledException
      throw FFmpegNotInstalledException();
    }
    
    // Esegui FFprobe
    final args = [
      '-v', 'quiet',
      '-print_format', 'json',
      '-show_format',
      '-show_streams',
      videoPath, // Path già normalizzato
    ];
    
    DebugLogger.debug('🔍 [Metadata Windows] Esecuzione FFprobe: ffprobe ${args.join(" ")}');
    
    final result = await Process.run('ffprobe', args);
    
    if (result.exitCode != 0) {
      final errorOutput = result.stderr.toString();
      DebugLogger.error('❌ [Metadata Windows] FFprobe fallito');
      DebugLogger.debug('   Exit code: ${result.exitCode}');
      DebugLogger.debug('   Error: $errorOutput');
      DebugLogger.debug('   Path: $videoPath');
      throw Exception('FFprobe failed: $errorOutput');
    }
    
    final output = result.stdout.toString();
    if (output.isEmpty) {
      throw Exception('FFprobe output vuoto - possibile problema con il file');
    }
    
    try {
      final jsonData = json.decode(output) as Map<String, dynamic>;
      return _parseMetadata(jsonData);
    } catch (e) {
      DebugLogger.error('❌ [Metadata Windows] Errore parsing JSON: $e');
      DebugLogger.debug('   Output: $output');
      throw Exception('Failed to parse FFprobe JSON output: $e');
    }
  }
}

