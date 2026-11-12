import 'dart:io';
import '../constants/app_constants.dart';

/// Utility per validare file video
class FileValidator {
  /// Formati video supportati
  static const List<String> allowedVideoFormats = [
    'mp4',
    'avi',
    'mov',
    'mkv',
    'webm',
  ];
  
  /// Verifica se un file è un video valido
  static bool isValidVideoFile(File file) {
    final extension = _getFileExtension(file.path);
    return allowedVideoFormats.contains(extension.toLowerCase());
  }
  
  /// Verifica se un file è un video valido (da path)
  static bool isValidVideoFileFromPath(String filePath) {
    final extension = _getFileExtension(filePath);
    return allowedVideoFormats.contains(extension.toLowerCase());
  }
  
  /// Verifica se un file è nascosto (inizia con .)
  static bool isHiddenFile(File file) {
    final fileName = file.path.split(Platform.pathSeparator).last;
    return fileName.startsWith('.');
  }
  
  /// Verifica se un file è nascosto (da path)
  static bool isHiddenFileFromPath(String filePath) {
    final fileName = filePath.split(Platform.pathSeparator).last;
    return fileName.startsWith('.');
  }
  
  /// Verifica dimensione file
  static Future<bool> isValidFileSize(File file) async {
    try {
      final fileSize = await file.length();
      return fileSize <= AppConstants.maxUploadSize && fileSize > 0;
    } catch (e) {
      return false;
    }
  }
  
  /// Valida file completo (formato + dimensione)
  static Future<FileValidationResult> validateFile(File file) async {
    // Verifica file esiste
    if (!await file.exists()) {
      return FileValidationResult(
        isValid: false,
        error: 'File non esiste',
      );
    }
    
    // Verifica non è nascosto
    if (isHiddenFile(file)) {
      return FileValidationResult(
        isValid: false,
        error: 'File nascosto ignorato',
      );
    }
    
    // Verifica formato
    if (!isValidVideoFile(file)) {
      final extension = _getFileExtension(file.path);
      return FileValidationResult(
        isValid: false,
        error: 'Formato non supportato: $extension. Formati supportati: ${allowedVideoFormats.join(", ")}',
      );
    }
    
    // Verifica dimensione
    final fileSize = await file.length();
    if (fileSize > AppConstants.maxUploadSize) {
      return FileValidationResult(
        isValid: false,
        error: 'File troppo grande: ${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB. Massimo: ${(AppConstants.maxUploadSize / (1024 * 1024 * 1024)).toStringAsFixed(0)} GB',
      );
    }
    
    if (fileSize == 0) {
      return FileValidationResult(
        isValid: false,
        error: 'File vuoto',
      );
    }
    
    return FileValidationResult(
      isValid: true,
      fileSize: fileSize,
    );
  }
  
  /// Estrae estensione file
  static String _getFileExtension(String filePath) {
    final parts = filePath.split('.');
    if (parts.length < 2) {
      return '';
    }
    return parts.last;
  }
}

/// Risultato validazione file
class FileValidationResult {
  final bool isValid;
  final String? error;
  final int? fileSize;
  
  FileValidationResult({
    required this.isValid,
    this.error,
    this.fileSize,
  });
}

