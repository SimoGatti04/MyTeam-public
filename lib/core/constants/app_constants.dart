/// Application constants
class AppConstants {
  // Override only for local development via --dart-define=MYTEAM_API_BASE_URL=...
  // Release builds keep the public production API as their safe default.
  static const String _baseUrl = String.fromEnvironment(
    'MYTEAM_API_BASE_URL',
    defaultValue: 'https://myteam.simogatti.it',
  );
  static String get baseUrl => _baseUrl;

  static String get apiBaseUrl => '$baseUrl/api';
  
  // Upload Configuration
  static const int maxUploadSize = 53687091200; // 50GB in bytes
  static const int maxRetries = 5;
  static const Duration uploadTimeout = Duration(hours: 24);
  
  // Chunked Upload Configuration
  static const int chunkSize = 90 * 1024 * 1024; // 90MB per chunk (sotto il limite Cloudflare di 100MB)
  static const int chunkedUploadThreshold = 100 * 1024 * 1024; // Usa chunked upload per file >100MB
  
  // Compression Configuration
  static const List<int> supportedResolutions = [
    480,  // 480p
    720,  // 720p
    1080, // 1080p
    1440, // 1440p
    2160, // 4K
  ];
  
  static const List<int> supportedFramerates = [
    24,
    30,
    60,
    120,
  ];
  
  // Storage Configuration
  static const String videosDirectory = 'videos';
  static const String tempDirectory = 'temp';
  
  // Multi-Upload Configuration
  static const int maxFilesPerBatch = 50; // Limite massimo file per batch
  static const int maxConcurrentUploads = 2; // Upload simultanei (0 = sequenziale)
  static const int maxFolderDepth = 3; // Profondità massima scansione cartelle
}

