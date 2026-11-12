import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:myteam/domain/entities/compression_settings.dart';
import 'package:myteam/domain/entities/upload_task.dart';
import 'package:myteam/domain/repositories/upload_repository.dart';
import 'package:myteam/domain/usecases/upload_video_usecase.dart';
import 'package:myteam/features/upload/viewmodels/upload_viewmodel.dart';
import 'package:myteam/core/services/updater/active_tasks_guard.dart';
import 'package:myteam/core/services/updater/update_service.dart';

class InMemoryUploadRepository implements UploadRepository {
  final List<UploadTask> tasks = [];
  bool shouldFail = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<UploadTask>> getActiveUploads() async {
    if (shouldFail) throw Exception('Simulated database error');
    return List.from(tasks);
  }

  @override
  Future<List<UploadTask>> getCompletedUploads({int limit = 10}) async {
    if (shouldFail) throw Exception('Simulated database error');
    return [];
  }

  @override
  Future<List<UploadTask>> loadSavedUploadTasks() async {
    if (shouldFail) throw Exception('Simulated database error');
    return List.from(tasks);
  }

  Future<void> saveUploadTask(UploadTask task) async {
    tasks.removeWhere((t) => t.id == task.id);
    tasks.add(task);
  }

  @override
  Future<void> cancelUpload(String taskId) async {
    tasks.removeWhere((t) => t.id == taskId);
  }
}

void main() {
  group('UploadViewModel & ActiveTasksGuard Integration Lifecycle', () {
    test('Demonstrates uninitialized state blocks, initialized unblocks, active task blocks, and install lock rejects new uploads', () async {
      final repo = InMemoryUploadRepository();
      final useCase = UploadVideoUseCase(repo);
      final viewModel = UploadViewModel(useCase);

      final guard = ActiveTasksGuard(uploadViewModel: viewModel);
      final updateService = UpdateService.instance;
      updateService.setGuard(guard);

      // 1. Stato non inizializzato -> Fail-Closed BLOCKS
      expect(viewModel.isInitialized, isFalse);
      expect(guard.hasActiveOperations, isTrue);

      // 2. Inizializzazione completata senza task attivi -> ALLOWS
      await viewModel.loadSavedUploadTasks();
      expect(viewModel.isInitialized, isTrue);
      expect(guard.hasActiveOperations, isFalse);

      // 3. Aggiunta task attivo (upload) -> BLOCKS
      final tempDir = await Directory.systemTemp.createTemp('integ_upload_');
      final dummyFile = File('${tempDir.path}/match.mp4')..writeAsStringSync('video content');

      viewModel.queueUpload(
        videoFile: dummyFile,
        title: 'Campionato Under 17',
        compressionSettings: const CompressionSettings(keepOriginal: true),
      );

      expect(viewModel.hasActiveTasks || viewModel.isProcessingQueue || viewModel.queueLength > 0, isTrue);
      expect(guard.hasActiveOperations, isTrue);

      // 4. Se la modalità di installazione viene attivata -> BLOCKS ed impedisce nuovi upload
      viewModel.setInstallationInProgress(true);
      expect(guard.hasActiveOperations, isTrue);

      final secondFile = File('${tempDir.path}/second.mp4')..writeAsStringSync('video content 2');
      viewModel.queueUpload(
        videoFile: secondFile,
        title: 'Tentativo durante installazione',
        compressionSettings: const CompressionSettings(keepOriginal: true),
      );

      expect(viewModel.error, contains('Impossibile avviare caricamenti durante'));

      await tempDir.delete(recursive: true);
    });
  });
}
