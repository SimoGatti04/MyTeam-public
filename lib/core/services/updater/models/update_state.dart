import 'update_manifest.dart';

/// Stato attuale dell'updater autonomo
enum UpdateFailureKind { serviceUnavailable, security, operation }

enum UpdateStatus {
  idle,
  checking,
  upToDate,
  updateAvailable,
  downloading,
  verifying,
  readyToInstall,
  blockedByActiveTasks,
  installing,
  handoffToSystemInstaller,
  failed,
}

class UpdateState {
  final UpdateStatus status;
  final UpdateFailureKind? failureKind;
  final UpdateManifest? manifest;
  final UpdateArtifact? artifact;
  final double progress; // 0.0 -> 1.0
  final int downloadedBytes;
  final int totalBytes;
  final String? downloadedFilePath;
  final String? errorMessage;
  final String? activeTasksDescription;

  const UpdateState({
    this.status = UpdateStatus.idle,
    this.failureKind,
    this.manifest,
    this.artifact,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.downloadedFilePath,
    this.errorMessage,
    this.activeTasksDescription,
  });

  UpdateState copyWith({
    UpdateStatus? status,
    UpdateFailureKind? failureKind,
    bool clearFailure = false,
    UpdateManifest? manifest,
    UpdateArtifact? artifact,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    String? downloadedFilePath,
    String? errorMessage,
    String? activeTasksDescription,
  }) {
    return UpdateState(
      status: status ?? this.status,
      failureKind: clearFailure ? null : failureKind ?? this.failureKind,
      manifest: manifest ?? this.manifest,
      artifact: artifact ?? this.artifact,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedFilePath: downloadedFilePath ?? this.downloadedFilePath,
      errorMessage: clearFailure ? null : errorMessage ?? this.errorMessage,
      activeTasksDescription:
          activeTasksDescription ?? this.activeTasksDescription,
    );
  }
}
