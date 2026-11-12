/// Compression settings entity - Domain layer
class CompressionSettings {
  final int? resolutionWidth;
  final int? resolutionHeight;
  final double? framerate;
  final bool keepOriginal;
  
  const CompressionSettings({
    this.resolutionWidth,
    this.resolutionHeight,
    this.framerate,
    this.keepOriginal = false,
  });
  
  /// Get standard resolution by name
  static CompressionSettings fromResolutionName(String name) {
    switch (name.toLowerCase()) {
      case '480p':
        return const CompressionSettings(
          resolutionWidth: 854,
          resolutionHeight: 480,
        );
      case '720p':
        return const CompressionSettings(
          resolutionWidth: 1280,
          resolutionHeight: 720,
        );
      case '1080p':
        return const CompressionSettings(
          resolutionWidth: 1920,
          resolutionHeight: 1080,
        );
      case '1440p':
        return const CompressionSettings(
          resolutionWidth: 2560,
          resolutionHeight: 1440,
        );
      case '2160p':
      case '4k':
        return const CompressionSettings(
          resolutionWidth: 3840,
          resolutionHeight: 2160,
        );
      case 'original':
      default:
        return const CompressionSettings(keepOriginal: true);
    }
  }
  
  /// Get standard resolution names
  static List<String> getResolutionNames() {
    return ['480p', '720p', '1080p', '1440p', '2160p', 'Original'];
  }
  
  /// Get standard framerates
  static List<double> getStandardFramerates() {
    return [24.0, 30.0, 60.0, 120.0];
  }
}

