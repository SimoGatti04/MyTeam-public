import 'dart:io';
import 'package:flutter/foundation.dart';
import 'file_validator.dart';
import '../services/debug_logger.dart';

/// Utility per scansionare cartelle e trovare file video validi
class FolderScanner {
  /// Scansiona una cartella ricorsivamente e trova tutti i file video validi
  /// 
  /// [folderPath] - Path della cartella da scansionare
  /// [maxDepth] - Profondità massima di scansione (default: 3)
  /// [onProgress] - Callback chiamato durante la scansione con (filesFound, currentPath)
  /// 
  /// Returns: Lista di file video validi trovati
  static Future<List<File>> scanFolderForVideos({
    required String folderPath,
    int maxDepth = 3,
    Function(int filesFound, String? currentPath)? onProgress,
  }) async {
    final folder = Directory(folderPath);
    
    if (!await folder.exists()) {
      throw Exception('Cartella non esiste: $folderPath');
    }
    
    final validFiles = <File>[];
    int filesFound = 0;
    
    await _scanDirectoryRecursive(
      folder,
      maxDepth: maxDepth,
      currentDepth: 0,
      validFiles: validFiles,
      filesFound: filesFound,
      onProgress: (found, currentPath) {
        filesFound = found;
        onProgress?.call(found, currentPath);
      },
    );
    
    return validFiles;
  }
  
  /// Scansione ricorsiva di una directory
  static Future<void> _scanDirectoryRecursive(
    Directory directory, {
    required int maxDepth,
    required int currentDepth,
    required List<File> validFiles,
    required int filesFound,
    required Function(int, String?) onProgress,
  }) async {
    if (currentDepth >= maxDepth) {
      return;
    }
    
    try {
      await for (final entity in directory.list()) {
        // Aggiorna progress con path corrente
        onProgress(filesFound, entity.path);
        
        if (entity is File) {
          // Verifica se è un file video valido
          if (FileValidator.isValidVideoFileFromPath(entity.path) &&
              !FileValidator.isHiddenFileFromPath(entity.path)) {
            // Valida file completo (formato + dimensione)
            final validation = await FileValidator.validateFile(entity);
            if (validation.isValid) {
              validFiles.add(entity);
              filesFound++;
              onProgress(filesFound, entity.path);
            } else {
              DebugLogger.debug('⚠️ [FolderScanner] File ignorato: ${entity.path} - ${validation.error}');
            }
          }
        } else if (entity is Directory) {
          // Ignora cartelle nascoste
          if (!FileValidator.isHiddenFileFromPath(entity.path)) {
            // Continua ricorsione
            await _scanDirectoryRecursive(
              entity,
              maxDepth: maxDepth,
              currentDepth: currentDepth + 1,
              validFiles: validFiles,
              filesFound: filesFound,
              onProgress: onProgress,
            );
          }
        }
      }
    } catch (e) {
      // Ignora errori di accesso (permessi, ecc.)
      DebugLogger.warning('⚠️ [FolderScanner] Errore accesso directory ${directory.path}: $e');
    }
  }
}

