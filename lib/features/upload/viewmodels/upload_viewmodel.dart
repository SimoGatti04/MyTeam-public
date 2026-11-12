import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../../domain/entities/video.dart';
import '../../../domain/entities/upload_task.dart';
import '../../../domain/entities/compression_settings.dart';
import '../../../domain/usecases/upload_video_usecase.dart';
import '../../../core/services/upload_cancellation_service.dart';
import '../../../core/services/debug_logger.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/video_metadata_service.dart';
import '../services/video_compression_service.dart';

/// Classe per rappresentare un upload in coda
class _QueuedUpload {
  final File videoFile;
  final String title;
  final CompressionSettings compressionSettings;
  final DateTime? recordedDate;
  
  _QueuedUpload({
    required this.videoFile,
    required this.title,
    required this.compressionSettings,
    this.recordedDate,
  });
}

/// Upload view model - Presentation layer
/// Gestisce upload sequenziali: un file alla volta dalla coda
class UploadViewModel extends ChangeNotifier {
  final UploadVideoUseCase uploadUseCase;
  
  UploadViewModel(this.uploadUseCase);
  
  // State - Task corrente in esecuzione
  UploadTask? _currentUploadTask;
  double _currentTaskProgress = 0.0;
  String? _currentTaskStatusMessage;
  bool _currentTaskIsCompressing = false;
  
  // State - Lista task (per storico e completati)
  List<UploadTask> _uploadTasks = [];
  
  // State - Coda sequenziale
  final List<_QueuedUpload> _uploadQueue = [];
  bool _isProcessingQueue = false;
  
  // State - Errori
  String? _error;

  // State - Inizializzazione e protezione aggiornamenti
  bool _isInitialized = false;
  bool _isLoadingTasks = false;
  String? _initError;
  bool _isInstallationInProgress = false;
  
  // Getters
  List<UploadTask> get uploadTasks => _uploadTasks;
  UploadTask? get currentUploadTask => _currentUploadTask;
  double get uploadProgress => _currentTaskProgress;
  double get compressionProgress => _currentTaskProgress;
  String? get uploadStatusMessage => _currentTaskStatusMessage;
  String? get compressionStatusMessage => _currentTaskStatusMessage;
  bool get isUploading => _currentUploadTask?.status == UploadStatus.uploading;
  bool get isCompressing => _currentUploadTask?.status == UploadStatus.compressing;
  String? get error => _error;
  int get queueLength => _uploadQueue.length;
  bool get isProcessingQueue => _isProcessingQueue;
  bool get isInitialized => _isInitialized;
  bool get isLoadingTasks => _isLoadingTasks;
  String? get initError => _initError;
  bool get isInstallationInProgress => _isInstallationInProgress;
  bool get hasActiveTasks => _uploadTasks.any((task) =>
      task.status == UploadStatus.uploading ||
      task.status == UploadStatus.compressing ||
      task.status == UploadStatus.queued ||
      task.status == UploadStatus.scanning);

  /// Tenta di acquisire atomicamente il lock di installazione.
  /// Ritorna true solo se non vi sono operazioni attive, l'inizializzazione è riuscita
  /// e il lock non era già stato acquisito.
  bool acquireInstallationLock() {
    if (!_isInitialized || _initError != null || _isInstallationInProgress) {
      return false;
    }
    if (isCompressing || isUploading || isProcessingQueue || queueLength > 0 || hasActiveTasks) {
      return false;
    }
    _isInstallationInProgress = true;
    notifyListeners();
    return true;
  }

  /// Rilascia il lock dell'installazione
  void releaseInstallationLock() {
    if (_isInstallationInProgress) {
      _isInstallationInProgress = false;
      notifyListeners();
    }
  }

  /// Blocca o sblocca nuove operazioni durante il passaggio di consegne all'installer di sistema
  void setInstallationInProgress(bool inProgress) {
    _isInstallationInProgress = inProgress;
    notifyListeners();
  }
  
  /// Aggiungi video alla coda di upload sequenziali
  void queueUpload({
    required File videoFile,
    required String title,
    required CompressionSettings compressionSettings,
    DateTime? recordedDate,
  }) {
    if (_isInstallationInProgress) {
      DebugLogger.warning('UploadViewModel: Operazione rifiutata: installazione aggiornamento in corso.');
      _error = 'Impossibile avviare caricamenti durante l\'installazione degli aggiornamenti.';
      notifyListeners();
      return;
    }
    _uploadQueue.add(_QueuedUpload(
      videoFile: videoFile,
      title: title,
      compressionSettings: compressionSettings,
      recordedDate: recordedDate,
    ));
    
    DebugLogger.debug('📥 [Queue] File aggiunto alla coda: ${videoFile.path} (${_uploadQueue.length} in coda)');
    
    // Avvia processamento coda se non è già in corso
    if (!_isProcessingQueue) {
      _processUploadQueue();
    }
    
    notifyListeners();
  }
  
  /// Processa la coda di upload sequenzialmente (un file alla volta)
  Future<void> _processUploadQueue() async {
    if (_isProcessingQueue || _uploadQueue.isEmpty) {
      return;
    }
    
    _isProcessingQueue = true;
    notifyListeners();
    
    DebugLogger.info('🚀 [Queue] Inizio processamento coda (${_uploadQueue.length} file)');
    
    while (_uploadQueue.isNotEmpty) {
      final queuedUpload = _uploadQueue.removeAt(0);
      
      DebugLogger.info('📤 [Queue] Processando file: ${queuedUpload.videoFile.path} (${_uploadQueue.length} rimanenti)');
      
      try {
        // Avvia upload del file corrente
        await _uploadVideoInternal(
          videoFile: queuedUpload.videoFile,
          title: queuedUpload.title,
          compressionSettings: queuedUpload.compressionSettings,
          recordedDate: queuedUpload.recordedDate,
        );
        
        DebugLogger.info('✅ [Queue] File completato: ${queuedUpload.videoFile.path}');
      } catch (e) {
        DebugLogger.error('❌ [Queue] Errore upload file ${queuedUpload.videoFile.path}: $e');
        // Continua con il prossimo file anche in caso di errore
      } finally {
        // Reset task corrente dopo ogni upload (completato o errore)
        _currentUploadTask = null;
        _currentTaskProgress = 0.0;
        _currentTaskStatusMessage = null;
        _currentTaskIsCompressing = false;
        _error = null;
        notifyListeners();
      }
    }
    
    _isProcessingQueue = false;
    DebugLogger.info('🏁 [Queue] Coda completata');
    notifyListeners();
  }
  
  /// Upload video with compression (metodo interno - processa un singolo file)
  Future<Video?> _uploadVideoInternal({
    required File videoFile,
    required String title,
    required CompressionSettings compressionSettings,
    DateTime? recordedDate,
  }) async {
    _error = null;
    notifyListeners();
    
    // Dichiarazione variabili fuori dal try per accesso nel catch
    File? compressedFile;
    
    try {
      // 1. Connectivity check
      await ConnectivityService.ensureOnline();
      
      // 2. Extract original metadata (opzionale - se fallisce, usa valori null)
      Map<String, dynamic>? originalMetadata;
      try {
        originalMetadata = await VideoMetadataService.extractMetadata(videoFile.path);
        DebugLogger.info('✅ [Upload] Metadata estratti con successo');
        DebugLogger.debug('   Duration: ${originalMetadata?['duration']}s');
        DebugLogger.debug('   Framerate: ${originalMetadata?['framerate']}fps');
        DebugLogger.debug('   Total frames: ${originalMetadata?['total_frames']}');
        DebugLogger.debug('   Resolution: ${originalMetadata?['width']}x${originalMetadata?['height']}');
      } on FFmpegNotInstalledException {
        // FFmpeg/FFprobe non installato: propaga l'eccezione per mostrare dialog
        rethrow;
      } catch (e, stackTrace) {
        DebugLogger.warning('⚠️ [Upload] Estrazione metadata fallita: $e');
        DebugLogger.debug('   Stack: $stackTrace');
        DebugLogger.info('   Continuo con upload senza metadata (valori null)');
        originalMetadata = null;
      }
      
      final originalTotalFrames = originalMetadata?['total_frames'] as int?;
      final originalDuration = originalMetadata?['duration'] as int?;
      final originalFramerateForCalculation = originalMetadata?['framerate'] as double?;
      
      // Calcola frame totali del video compresso (basato sul framerate di destinazione)
      int? totalFrames;
      if (compressionSettings.framerate != null && originalDuration != null) {
        totalFrames = (originalDuration * compressionSettings.framerate!).round();
        DebugLogger.debug('🎬 [Compression] Frame totali calcolati: $totalFrames (durata: ${originalDuration}s, framerate destinazione: ${compressionSettings.framerate}fps)');
      } else if (originalTotalFrames != null) {
        totalFrames = originalTotalFrames;
        DebugLogger.debug('🎬 [Compression] Frame totali originali: $totalFrames');
      } else if (originalDuration != null && originalFramerateForCalculation != null) {
        totalFrames = (originalDuration * originalFramerateForCalculation).round();
        DebugLogger.debug('🎬 [Compression] Frame totali calcolati da duration/framerate: $totalFrames');
      } else if (originalDuration != null && compressionSettings.framerate == null) {
        totalFrames = (originalDuration * 30).round();
        DebugLogger.warning('⚠️ [Compression] Frame totali stimati (30fps): $totalFrames');
      } else {
        final fileSizeMB = await videoFile.length() / (1024 * 1024);
        final estimatedDuration = (fileSizeMB / 1.0).round();
        totalFrames = (estimatedDuration * 30).round();
        DebugLogger.warning('⚠️ [Compression] Frame totali stimati da dimensione file: $totalFrames');
      }
      
      // 3. Compress video (if needed)
      int? originalFileSize;
      int? originalResolutionWidth;
      int? originalResolutionHeight;
      double? originalFramerate;
      UploadTask? compressionTask;
      
      if (!compressionSettings.keepOriginal) {
        // Crea compression task
        compressionTask = await uploadUseCase.createCompressionTask(
          localFilePath: videoFile.path,
          title: title,
          originalFileSize: await videoFile.length(),
          totalFrames: totalFrames,
        );
        
        // Aggiungi task alla lista
        final existingIndex = _uploadTasks.indexWhere((t) => t.id == compressionTask!.id);
        if (existingIndex != -1) {
          _uploadTasks[existingIndex] = compressionTask!;
        } else {
          _uploadTasks.add(compressionTask!);
        }
        
        // Imposta come task corrente
        _currentUploadTask = compressionTask;
        _currentTaskProgress = 0.0;
        _currentTaskStatusMessage = 'Compressing video...';
        _currentTaskIsCompressing = true;
        notifyListeners();
        
        // Compress video con progress tracking
        File compressedFileResult;
        try {
          compressedFileResult = await VideoCompressionService.compressVideoWithRetry(
            inputFile: videoFile,
            settings: compressionSettings,
            totalFrames: totalFrames,
            taskId: compressionTask!.id,
            originalMetadata: originalMetadata,
            onProgress: (progress, message, processedFrames) async {
              // Aggiorna task corrente
              if (_currentUploadTask?.id == compressionTask!.id) {
                _currentTaskProgress = progress;
                _currentTaskStatusMessage = message;
                
                // Aggiorna task nella lista E task corrente
                final index = _uploadTasks.indexWhere((t) => t.id == compressionTask!.id);
                if (index != -1) {
                  final updatedTask = _uploadTasks[index].copyWith(
                    progress: progress,
                    uploadedBytes: processedFrames,
                    status: UploadStatus.compressing,
                  );
                  _uploadTasks[index] = updatedTask;
                  // Aggiorna anche _currentUploadTask per sincronizzazione
                  _currentUploadTask = updatedTask;
                }
                
                // Notifica sempre per UI fluida (il callback viene già chiamato con frequenza ottimale)
                notifyListeners();
                
                // Aggiorna persistenza ogni 5% (meno frequente per performance)
                final progressPercent = (progress * 100).round();
                if (progressPercent % 5 == 0 || progressPercent == 100) {
                  uploadUseCase.updateCompressionProgress(
                    taskId: compressionTask!.id,
                    progress: progress,
                    processedFrames: processedFrames,
                    statusMessage: message,
                  ).catchError((e) {
                    DebugLogger.warning('⚠️ [Upload] Errore persistenza progress: $e');
                  });
                }
              }
            },
            onRetry: (attempt, error) {
              DebugLogger.info('🔄 [Compression] Retry attempt $attempt');
            },
            onFinalError: (finalError) {
              _error = 'Compression failed: $finalError';
              notifyListeners();
            },
          );
        } on FFmpegNotInstalledException {
          _currentUploadTask = null;
          _currentTaskProgress = 0.0;
          _currentTaskStatusMessage = null;
          _currentTaskIsCompressing = false;
          notifyListeners();
          rethrow;
        } catch (e) {
          if (e.toString().contains('cancelled') || e.toString().contains('cancel')) {
            DebugLogger.info('🛑 [Upload] Compressione cancellata');
            
            // Cleanup file compresso se esiste (potrebbe essere stato creato parzialmente)
            // Cerca file compresso nel task o nella cache temporanea
            if (compressionTask?.localFilePath != null) {
              await _cleanupCompressedFileByPath(compressionTask!.localFilePath, videoFile.path);
            }
            
            _currentUploadTask = null;
            _currentTaskProgress = 0.0;
            _currentTaskStatusMessage = null;
            _currentTaskIsCompressing = false;
            _error = 'Upload cancelled by user';
            notifyListeners();
            return null;
          }
          rethrow;
        }
        
        compressedFile = compressedFileResult;
        
        // Verifica file compresso
        if (!await compressedFile.exists()) {
          DebugLogger.error('❌ [Upload] File compresso non esiste');
          _error = 'Compressed file not found';
          _currentUploadTask = null;
          notifyListeners();
          return null;
        }
        
        final compressedFileSize = await compressedFile.length();
        if (compressedFileSize == 0) {
          DebugLogger.error('❌ [Upload] File compresso è vuoto');
          _error = 'Compressed file is empty';
          _currentUploadTask = null;
          notifyListeners();
          return null;
        }
        
        // Verifica se task è stato cancellato
        if (_currentUploadTask == null || _currentUploadTask!.status == UploadStatus.cancelled) {
          DebugLogger.info('🛑 [Upload] Task cancellata durante compressione');
          // Cleanup file compresso se esiste
          await _cleanupCompressedFile(compressedFile, videoFile);
          return null;
        }
        
        // Aggiorna task: compressione completata, ora inizia upload
        final index = _uploadTasks.indexWhere((t) => t.id == compressionTask!.id);
        if (index != -1) {
          _uploadTasks[index] = _uploadTasks[index].copyWith(
            status: UploadStatus.uploading,
            progress: 0.0,
            localFilePath: compressedFile.path,
          );
          _currentUploadTask = _uploadTasks[index];
          _currentTaskProgress = 0.0;
          _currentTaskStatusMessage = 'Preparing upload...';
          _currentTaskIsCompressing = false;
          
          await uploadUseCase.updateCompressionProgress(
            taskId: compressionTask!.id,
            progress: 1.0,
            processedFrames: totalFrames ?? 0,
            statusMessage: 'Compression completed',
          );
        }
        
        notifyListeners();
        
        originalFileSize = await videoFile.length();
        originalResolutionWidth = originalMetadata?['width'] as int?;
        originalResolutionHeight = originalMetadata?['height'] as int?;
        originalFramerate = originalMetadata?['framerate'] as double?;
      } else {
        // keepOriginal = true: usa file originale
        compressedFile = videoFile;
        originalFileSize = await videoFile.length();
        originalResolutionWidth = originalMetadata?['width'] as int?;
        originalResolutionHeight = originalMetadata?['height'] as int?;
        originalFramerate = originalMetadata?['framerate'] as double?;
        
        DebugLogger.info('📤 [Upload] keepOriginal=true, uso file originale');
      }
      
      // 4. Crea upload task
      UploadTask currentTask;
      
      if (!compressionSettings.keepOriginal && compressionTask != null) {
        // Usa task esistente (da compressione)
        final existingTaskIndex = _uploadTasks.indexWhere((t) => t.id == compressionTask!.id);
        if (existingTaskIndex != -1) {
          currentTask = _uploadTasks[existingTaskIndex].copyWith(
            localFilePath: compressedFile.path,
            totalBytes: originalFileSize ?? await compressedFile.length(),
            progress: 0.0,
          );
          _uploadTasks[existingTaskIndex] = currentTask;
          _currentUploadTask = currentTask;
        } else {
          // Crea nuovo task
          currentTask = await uploadUseCase.createUploadTask(
            localFilePath: compressedFile.path,
            title: title,
            originalFileSize: originalFileSize,
          );
          _uploadTasks.add(currentTask);
          _currentUploadTask = currentTask;
        }
      } else {
        // Crea nuovo task di upload
        currentTask = await uploadUseCase.createUploadTask(
          localFilePath: compressedFile.path,
          title: title,
          originalFileSize: originalFileSize,
        );
        _uploadTasks.add(currentTask);
        _currentUploadTask = currentTask;
      }
      
      _currentTaskProgress = 0.0;
      _currentTaskStatusMessage = 'Uploading video...';
      _currentTaskIsCompressing = false;
      notifyListeners();
      
      // 5. Upload video
      final uploadStartTime = DateTime.now();
      final fileSize = await compressedFile.length();
      DebugLogger.info('📤 [Upload] Inizio upload: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB');
      
      // Crea cancel token per questo upload
      final cancelToken = UploadCancellationService.createCancelToken(currentTask.id);
      
      final result = await uploadUseCase.execute(
        localFilePath: compressedFile.path,
        taskId: currentTask.id,
        title: title,
        originalResolutionWidth: originalResolutionWidth,
        originalResolutionHeight: originalResolutionHeight,
        originalFramerate: originalFramerate,
        compressedFramerate: compressionSettings.framerate,
        originalFileSize: originalFileSize,
        recordedDate: recordedDate,
        cancelToken: cancelToken, // Passa cancel token
        onProgress: (sent, total) {
          final progress = total > 0 ? sent / total : 0.0;
          
          // Aggiorna task corrente
          if (_currentUploadTask?.id == currentTask.id) {
            _currentTaskProgress = progress;
            _currentTaskStatusMessage = 'Uploading: ${(progress * 100).toStringAsFixed(1)}%';
            
            // Aggiorna task nella lista E task corrente
            final index = _uploadTasks.indexWhere((t) => t.id == currentTask.id);
            if (index != -1) {
              final updatedTask = _uploadTasks[index].copyWith(
                uploadedBytes: sent,
                progress: progress,
                status: UploadStatus.uploading,
              );
              _uploadTasks[index] = updatedTask;
              // Aggiorna anche _currentUploadTask per sincronizzazione
              _currentUploadTask = updatedTask;
            }
            
            // Notifica sempre per UI fluida (il callback viene già chiamato con frequenza ottimale)
            notifyListeners();
          }
        },
      );
      
      final uploadEndTime = DateTime.now();
      final uploadDuration = uploadEndTime.difference(uploadStartTime);
      DebugLogger.info('✅ [Upload] Upload completato in ${uploadDuration.inSeconds}s');
      
      // Rimuovi cancel token (upload completato)
      UploadCancellationService.removeCancelToken(currentTask.id);
      
      final video = result.video;
      final uploadTask = result.task;
      
      // Aggiorna task nella lista
      final index = _uploadTasks.indexWhere((t) => t.id == uploadTask.id);
      if (index != -1) {
        _uploadTasks[index] = uploadTask;
      } else {
        _uploadTasks.add(uploadTask);
      }
      
      // Cleanup compressed file
      await _cleanupCompressedFile(compressedFile, videoFile);
      
      // Ricarica task salvati (include completati)
      await loadSavedUploadTasks();
      
      return video;
    } catch (e) {
      _error = e.toString();
      DebugLogger.error('❌ [Upload] Upload fallito: $e');
      
      // Cleanup file compresso se esiste (diverso dal file originale)
      if (compressedFile != null) {
        await _cleanupCompressedFile(compressedFile, videoFile);
      }
      
      // Aggiorna task corrente come errore
      if (_currentUploadTask != null) {
        final errorTask = _currentUploadTask!.copyWith(
          status: UploadStatus.error,
          errorMessage: e.toString(),
        );
        final index = _uploadTasks.indexWhere((t) => t.id == _currentUploadTask!.id);
        if (index != -1) {
          _uploadTasks[index] = errorTask;
        }
      }
      
      notifyListeners();
      return null;
    }
  }
  
  /// Carica upload task salvati all'avvio
  Future<void> loadSavedUploadTasks() async {
    // Evita chiamate concorrenti
    if (_isLoadingTasks) return;
    _isLoadingTasks = true;
    _initError = null;
    _error = null;
    notifyListeners();

    try {
      final activeTasks = await uploadUseCase.getActiveUploads();
      final completedTasks = await uploadUseCase.getCompletedUploads(limit: 5);

      final allTasks = <String, UploadTask>{};
      for (final task in activeTasks) {
        allTasks[task.id] = task;
      }
      for (final task in completedTasks) {
        allTasks[task.id] = task;
      }

      // Mantieni task corrente se esiste
      if (_currentUploadTask != null) {
        allTasks[_currentUploadTask!.id] = _currentUploadTask!;
      }

      // Filtra task cancellate
      _uploadTasks = allTasks.values.where((task) =>
        task.status != UploadStatus.cancelled
      ).toList();

      // Trova un task attivo in modo sicuro senza crash su lista vuota
      UploadTask? activeTask;
      try {
        activeTask = _uploadTasks.firstWhere(
          (task) => task.status == UploadStatus.uploading ||
                    task.status == UploadStatus.compressing,
        );
      } catch (_) {
        activeTask = null;
      }

      if (activeTask != null) {
        if (_currentUploadTask?.id != activeTask.id) {
          _currentUploadTask = activeTask;
          _currentTaskProgress = activeTask.progress;
          if (activeTask.status == UploadStatus.compressing) {
            _currentTaskStatusMessage = 'Compressing: ${(activeTask.progress * 100).toStringAsFixed(1)}%';
            _currentTaskIsCompressing = true;
          } else {
            _currentTaskStatusMessage = 'Uploading: ${(activeTask.progress * 100).toStringAsFixed(1)}%';
            _currentTaskIsCompressing = false;
          }
        }
      }

      // Inizializzazione riuscita
      _isInitialized = true;
      _initError = null;

      // La pulizia dei file compressi vecchi avviene SOLO DOPO aver caricato i task persistiti
      // per proteggere tutti i file associati a task attivi o recuperabili
      _cleanupOldCompressedFiles().catchError((e) {
        DebugLogger.warning('⚠️ [Cleanup] Errore pulizia file vecchi all\'avvio: $e');
      });
    } catch (e) {
      _initError = e.toString();
      _error = 'Failed to load upload tasks: $e';
      _isInitialized = false; // FAIL-CLOSED: rimane non inizializzato se fallisce
    } finally {
      _isLoadingTasks = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
  
  /// Helper per pulire file compresso temporaneo
  /// Rimuove il file compresso se diverso dal file originale
  Future<void> _cleanupCompressedFile(File? compressedFile, File? originalFile) async {
    if (compressedFile == null) return;
    if (originalFile != null && compressedFile.path == originalFile.path) return;
    
    try {
      if (await compressedFile.exists()) {
        await compressedFile.delete();
        DebugLogger.info('🗑️ [Cleanup] File compresso rimosso: ${compressedFile.path}');
      }
    } catch (e) {
      DebugLogger.warning('⚠️ [Cleanup] Errore rimozione file compresso: $e');
    }
  }
  
  /// Helper per pulire file compresso da path (quando il File non è disponibile)
  Future<void> _cleanupCompressedFileByPath(String? compressedFilePath, String? originalFilePath) async {
    if (compressedFilePath == null || compressedFilePath.isEmpty) return;
    if (originalFilePath != null && compressedFilePath == originalFilePath) return;
    
    try {
      final file = File(compressedFilePath);
      if (await file.exists()) {
        await file.delete();
        DebugLogger.info('🗑️ [Cleanup] File compresso rimosso: $compressedFilePath');
      }
    } catch (e) {
      DebugLogger.warning('⚠️ [Cleanup] Errore rimozione file compresso: $e');
    }
  }
  
  /// Pulisce file compressi vecchi/abbandonati dalla cache temporanea
  /// Rimuove file compressi più vecchi di 24 ore che non sono associati a task attivi
  Future<void> _cleanupOldCompressedFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final directory = Directory(tempDir.path);
      
      if (!await directory.exists()) {
        return;
      }
      
      // Lista tutti i file nella cache temporanea
      final files = await directory.list().toList();
      final now = DateTime.now();
      final maxAge = const Duration(hours: 24);
      
      // Raccogli path di file compressi associati a task attivi
      final activeCompressedPaths = _uploadTasks
          .where((task) => 
              task.status == UploadStatus.uploading || 
              task.status == UploadStatus.compressing ||
              task.status == UploadStatus.queued)
          .map((task) => task.localFilePath)
          .where((path) => path != null && path.contains('compressed_'))
          .cast<String>()
          .toSet();
      
      int cleanedCount = 0;
      int totalSize = 0;
      
      for (final entity in files) {
        if (entity is File && entity.path.contains('compressed_') && entity.path.endsWith('.mp4')) {
          // Salta se il file è associato a un task attivo
          if (activeCompressedPaths.contains(entity.path)) {
            continue;
          }
          
          try {
            final stat = await entity.stat();
            final age = now.difference(stat.modified);
            
            // Rimuovi file più vecchi di 24 ore
            if (age > maxAge) {
              totalSize += stat.size;
              await entity.delete();
              cleanedCount++;
              DebugLogger.debug('🗑️ [Cleanup] File compresso vecchio rimosso: ${entity.path} (età: ${age.inHours}h)');
            }
          } catch (e) {
            // Ignora errori su singoli file (potrebbero essere stati eliminati)
            DebugLogger.debug('⚠️ [Cleanup] Errore accesso file: ${entity.path} - $e');
          }
        }
      }
      
      if (cleanedCount > 0) {
        DebugLogger.info('🧹 [Cleanup] Rimossi $cleanedCount file compressi vecchi (${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB)');
      }
    } catch (e) {
      DebugLogger.warning('⚠️ [Cleanup] Errore pulizia file compressi vecchi: $e');
    }
  }
  
  /// Cancella upload corrente
  Future<void> cancelUpload(String taskId) async {
    try {
      final task = _uploadTasks.firstWhere(
        (t) => t.id == taskId,
        orElse: () => _currentUploadTask ?? _uploadTasks.first,
      );
      
      // Se il task è in compressione, ferma la compressione FFmpeg
      if (task.status == UploadStatus.compressing) {
        DebugLogger.info('🛑 [Cancel] Fermando compressione FFmpeg per task: $taskId');
        await VideoCompressionService.cancelCompression(taskId);
      }
      
      // Se il task è in upload, ferma la richiesta HTTP
      if (task.status == UploadStatus.uploading) {
        DebugLogger.info('🛑 [Cancel] Fermando upload HTTP per task: $taskId');
        UploadCancellationService.cancelUpload(taskId);
      }
      
      // Cancella il task nel repository
      await uploadUseCase.cancelUpload(taskId);
      
      // Cleanup file compresso se esiste (diverso dal file originale)
      // Il file originale non viene mai eliminato, solo le copie compresse
      if (task.localFilePath != null) {
        // Verifica se è un file compresso (contiene "compressed_" nel nome)
        if (task.localFilePath!.contains('compressed_')) {
          await _cleanupCompressedFileByPath(task.localFilePath, null);
        }
      }
      
      // Aggiorna lista task
      final index = _uploadTasks.indexWhere((task) => task.id == taskId);
      if (index != -1) {
        _uploadTasks[index] = _uploadTasks[index].copyWith(status: UploadStatus.cancelled);
      }
      
      // Se era il task corrente, resettalo
      if (_currentUploadTask?.id == taskId) {
        _currentUploadTask = null;
        _currentTaskProgress = 0.0;
        _currentTaskStatusMessage = null;
        _currentTaskIsCompressing = false;
      }
      
      DebugLogger.info('✅ [Cancel] Task $taskId cancellata con successo');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to cancel upload: $e';
      DebugLogger.error('❌ [Cancel] Errore durante cancellazione: $e');
      notifyListeners();
    }
  }
  
  /// Cancella tutti i task attivi
  Future<void> cancelAllActiveTasks() async {
    try {
      await VideoCompressionService.cancelAllCompressions();
      
      final activeTasks = _uploadTasks.where(
        (task) => task.status == UploadStatus.uploading || 
                  task.status == UploadStatus.compressing
      ).toList();
      
      for (final task in activeTasks) {
        await cancelUpload(task.id);
      }
      
      // Svuota anche la coda
      _uploadQueue.clear();
      _isProcessingQueue = false;
      
      DebugLogger.info('✅ [Cancel] Tutte le task attive sono state cancellate');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to cancel all tasks: $e';
      DebugLogger.error('❌ [Cancel] Errore cancellazione task: $e');
      notifyListeners();
    }
  }
  
  /// Pulisci task completate
  Future<void> clearCompletedTasks() async {
    try {
      final tasksToRemove = _uploadTasks.where(
        (task) => task.status == UploadStatus.completed || 
                  task.status == UploadStatus.cancelled ||
                  task.status == UploadStatus.error
      ).toList();
      
      for (final task in tasksToRemove) {
        await uploadUseCase.cancelUpload(task.id);
        _uploadTasks.removeWhere((t) => t.id == task.id);
      }
      
      DebugLogger.info('✅ [Clear] Task completate/cancellate rimosse');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to clear completed tasks: $e';
      DebugLogger.error('❌ [Clear] Errore pulizia task: $e');
      notifyListeners();
    }
  }
  
  /// Cancella tutti gli upload in coda
  void clearUploadQueue() {
    _uploadQueue.clear();
    notifyListeners();
  }
}
