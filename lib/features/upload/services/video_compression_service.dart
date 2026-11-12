import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/session.dart';
import 'package:path_provider/path_provider.dart';
import '../../../domain/entities/compression_settings.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/settings_service.dart' as settings_service;
import '../../../core/services/debug_logger.dart';

/// Eccezione per FFmpeg non installato (per gestione speciale)
class FFmpegNotInstalledException implements Exception {
  @override
  String toString() => 'FFmpeg non installato. L\'app può aiutarti a installarlo automaticamente.';
}

/// Video compression service - Feature layer
class VideoCompressionService {
  static const int maxRetries = AppConstants.maxRetries;
  
  // Mappa per tenere traccia delle sessioni FFmpeg attive per task
  static final Map<String, Session> _activeSessions = {};
  // Mappa per tenere traccia delle task cancellate (per evitare retry)
  static final Set<String> _cancelledTasks = {};
  // Mappa per tenere traccia dei completer attivi per task (per completarli quando si cancella)
  static final Map<String, Completer<ReturnCode?>> _activeCompleters = {};
  
  /// Compress video with retry logic
  static Future<File> compressVideoWithRetry({
    required File inputFile,
    required CompressionSettings settings,
    Function(double progress, String message, int processedFrames)? onProgress,
    required Function(int attempt, String? error) onRetry,
    required Function(String finalError) onFinalError,
    int? totalFrames, // Numero totale di frame (per progress tracking preciso)
    String? taskId, // ID del task di compressione (per aggiornare progress)
    Map<String, dynamic>? originalMetadata, // Metadata originali per ottimizzazioni
  }) async {
    final errorLog = <String>[];
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      // Verifica se la task è stata cancellata prima di continuare
      if (taskId != null && _cancelledTasks.contains(taskId)) {
        DebugLogger.info('🛑 [Compression] Task $taskId è stata cancellata, interrompo retry');
        throw Exception('Compression cancelled by user');
      }
      
      try {
        final compressedFile = await compressVideo(
          inputFile: inputFile,
          settings: settings,
          onProgress: onProgress,
          totalFrames: totalFrames,
          taskId: taskId,
          originalMetadata: originalMetadata,
        );
        return compressedFile;
      } catch (e) {
        final error = e.toString();
        errorLog.add('Attempt $attempt: $error');
        
        // Se la task è stata cancellata, non fare retry
        if (taskId != null && _cancelledTasks.contains(taskId)) {
          DebugLogger.info('🛑 [Compression] Task $taskId è stata cancellata, interrompo retry');
          throw Exception('Compression cancelled by user');
        }
        
        // Se l'errore è dovuto alla cancellazione, non fare retry
        if (error.contains('cancelled') || error.contains('cancel')) {
          DebugLogger.info('🛑 [Compression] Compressione cancellata, interrompo retry');
          throw Exception('Compression cancelled by user');
        }
        
        if (attempt < maxRetries) {
          // Silent retry (no notification to user)
          onRetry(attempt, error);
          // Exponential backoff: 2^attempt seconds
          await Future.delayed(Duration(seconds: 1 << attempt));
        } else {
          // Final failure - notify user
          final finalError = errorLog.join('\n');
          onFinalError(finalError);
          rethrow;
        }
      }
    }
    
    throw Exception('Compression failed after $maxRetries attempts');
  }
  
  /// Compress video file
  static Future<File> compressVideo({
    required File inputFile,
    required CompressionSettings settings,
    Function(double progress, String message, int processedFrames)? onProgress,
    int? totalFrames, // Numero totale di frame (per progress tracking preciso)
    String? taskId, // ID del task di compressione
    Map<String, dynamic>? originalMetadata, // Metadata originali per ottimizzazioni
    bool forceSoftwareEncoding = false, // Forza software encoding (per fallback)
  }) async {
    if (settings.keepOriginal) {
      // No compression needed
      if (onProgress != null) {
        onProgress(1.0, 'No compression needed', totalFrames ?? 0);
      }
      return inputFile;
    }
    
    final startTime = DateTime.now();
    final inputSize = await inputFile.length();
    DebugLogger.debug('🎬 [Compression] Inizio compressione: ${(inputSize / (1024 * 1024)).toStringAsFixed(2)} MB');
    
    // Get temporary directory
    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.mp4';
    
    // Determina se usare hardware encoding (per fallback)
    // Dichiarato fuori dal try per essere accessibile in tutto il metodo
    final useHardware = forceSoftwareEncoding ? false : _supportsHardwareAcceleration();
    
    // Build FFmpeg command ottimizzato (usa metadata passati come parametro)
    // Se forceSoftwareEncoding è true, forza software encoding anche se hardware è disponibile
    final command = _buildOptimizedCompressionCommand(
      inputPath: inputFile.path,
      outputPath: outputPath,
      settings: settings,
      originalMetadata: originalMetadata,
      forceSoftwareEncoding: forceSoftwareEncoding,
    );
    
    // Windows: usa Process.run per eseguire FFmpeg direttamente (richiede FFmpeg installato)
    if (Platform.isWindows) {
      return await _compressVideoWindows(
        inputFile: inputFile,
        outputPath: outputPath,
        settings: settings,
        onProgress: onProgress,
        totalFrames: totalFrames,
        taskId: taskId,
        originalMetadata: originalMetadata,
        command: command,
      );
    }
    
    // Execute FFmpeg con progress tracking basato su frame processati (macOS/Android)
    String? failStackTrace;
    Timer? fallbackTimer; // Dichiarato fuori dal try per essere accessibile nel catch
    Session? sessionRef; // Dichiarato fuori dal try per essere accessibile nel catch
    int lastProcessedFrames = 0;
    final compressionStartTime = DateTime.now();
    
    try {
      // Log solo in modalità debug per ridurre verbosità
      DebugLogger.debug('🎬 [Compression] Inizio compressione (frame totali: ${totalFrames ?? "N/A"})');
      
      // Usa Completer per aspettare il completamento della sessione
      final completer = Completer<ReturnCode?>();
      
      // Salva il completer nella mappa se abbiamo un taskId (per completarlo quando si cancella)
      if (taskId != null) {
        _activeCompleters[taskId] = completer;
      }
      
      if (onProgress != null && totalFrames != null && totalFrames > 0) {
        // Timer fallback ogni 1 secondo per aggiornare progress basato su tempo
        fallbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          // Se non abbiamo ricevuto aggiornamenti recenti, usa stima basata su tempo
          final elapsed = DateTime.now().difference(compressionStartTime);
          final elapsedSeconds = elapsed.inSeconds;
          
          // Stima durata totale (assumendo ~2 secondi per MB)
          final estimatedDuration = (inputSize / (1024 * 1024) * 2).round();
          
          if (estimatedDuration > 0 && elapsedSeconds > 0) {
            // Progress basato su tempo (fallback)
            final timeBasedProgress = (elapsedSeconds / estimatedDuration).clamp(0.0, 0.95);
            
            // Usa il progresso basato su tempo solo se è maggiore dell'ultimo progresso basato su frame
            // Questo evita che il progresso vada indietro
            if (timeBasedProgress > (lastProcessedFrames / totalFrames)) {
              final estimatedFrames = (totalFrames * timeBasedProgress).round();
              final progressPercent = (timeBasedProgress * 100).toStringAsFixed(1);
              onProgress(timeBasedProgress, 'Compressing: $progressPercent% (estimated)', estimatedFrames);
            }
          }
        });
      }
      
      // Usa executeAsync per ottenere statistics callback con frame processati
      sessionRef = await FFmpegKit.executeAsync(
        command,
        (session) async {
          // Verifica se la task è stata cancellata prima di aggiornare il progresso
          final wasCancelled = taskId != null && _cancelledTasks.contains(taskId);
          
          // Rimuovi dalla mappa delle sessioni attive, dalle task cancellate e dai completer
          if (taskId != null) {
            _activeSessions.remove(taskId);
            _cancelledTasks.remove(taskId);
            _activeCompleters.remove(taskId);
          }
          
          // Session completed - aggiorna progress a 100% solo se non è stata cancellata
          if (!wasCancelled) {
            if (onProgress != null && totalFrames != null) {
              onProgress(1.0, 'Compressing: 100.0%', totalFrames);
            } else if (onProgress != null) {
              onProgress(1.0, 'Compressing: 100.0%', 0);
            }
          }
          
          // Completa il completer quando la sessione finisce
          final returnCode = await session.getReturnCode();
          if (!completer.isCompleted) {
            completer.complete(returnCode);
          }
        },
        null, // Log callback
        (statistics) {
          // Verifica se la task è stata cancellata prima di aggiornare il progresso
          if (taskId != null && _cancelledTasks.contains(taskId)) {
            DebugLogger.debug('🛑 [Compression] Task $taskId cancellata, ignoro aggiornamento progresso');
            return;
          }
          
          // Statistics callback - aggiorna progress basato su frame processati
          // Usa sempre frame-based progress (più affidabile del time-based)
          if (onProgress != null && totalFrames != null && totalFrames > 0) {
            final videoFrameNumber = statistics.getVideoFrameNumber();
            
            if (videoFrameNumber > 0) {
              lastProcessedFrames = videoFrameNumber; // Aggiorna ultimo frame processato
              
              // Calcola progress: frame processati / frame totali
              // Usa min per evitare che il progresso superi 1.0 prima del completamento
              final progress = (videoFrameNumber / totalFrames).clamp(0.0, 0.99); // Max 99% fino a completamento
              final progressPercent = (progress * 100).toStringAsFixed(1);
              
              // Log ogni 10% per Android (più frequente per debugging), ogni 25% per altri
              final progressPercentInt = (progress * 100).round();
              if (Platform.isAndroid) {
                if (progressPercentInt % 10 == 0 || progressPercentInt == 99) {
                  DebugLogger.debug('🎬 [Compression] Android Progress: $progressPercent% (frame $videoFrameNumber/$totalFrames)');
                }
              } else {
                if (videoFrameNumber % (totalFrames ~/ 4) == 0 || videoFrameNumber == totalFrames) {
                  DebugLogger.debug('🎬 [Compression] Progress: $progressPercent% (frame $videoFrameNumber/$totalFrames)');
                }
              }
              
              onProgress(progress, 'Compressing: $progressPercent% (frame $videoFrameNumber/$totalFrames)', videoFrameNumber);
            }
          } else if (onProgress != null) {
            // Fallback: progress basato su tempo se non abbiamo frame totali
            final time = statistics.getTime();
            if (time > 0) {
              // Stima basata su tempo (meno preciso)
              final estimatedDuration = (inputSize / (1024 * 1024) * 2).round(); // ~2 secondi per MB
              if (estimatedDuration > 0) {
                final progress = (time / estimatedDuration).clamp(0.0, 0.99);
                final progressPercent = (progress * 100).toStringAsFixed(1);
                // Stima frame processati basata su progress
                final estimatedFrames = (totalFrames ?? 0) * progress;
                onProgress(progress, 'Compressing: $progressPercent%', estimatedFrames.round());
              }
            }
          }
        },
      );
      
      // Salva la sessione nella mappa se abbiamo un taskId
      if (taskId != null) {
        _activeSessions[taskId] = sessionRef;
      }
      
      // Ferma timer fallback quando la sessione inizia
      // (il timer continuerà fino a quando non viene fermato esplicitamente)
      
      // Aspetta che la sessione completi (con timeout ottimizzato per piattaforma)
      // Android: timeout più lungo (2 ore) per gestire compressioni lunghe
      // Altri: 1 ora è sufficiente
      final timeoutDuration = Platform.isAndroid
          ? const Duration(hours: 2)  // Android: più tempo per compressioni lunghe
          : const Duration(hours: 1);  // Altri: 1 ora
      
      // Verifica periodicamente se la task è stata cancellata
      ReturnCode? returnCode;
      try {
        returnCode = await completer.future.timeout(
          timeoutDuration,
          onTimeout: () {
            DebugLogger.warning('⚠️ [Compression] Timeout in attesa del completamento (${timeoutDuration.inHours}h)');
            fallbackTimer?.cancel();
            return null;
          },
        );
      } catch (e) {
        // Se la task è stata cancellata, interrompi l'attesa
        if (taskId != null && _cancelledTasks.contains(taskId)) {
          DebugLogger.info('🛑 [Compression] Task $taskId cancellata durante l\'attesa, interrompo');
          fallbackTimer?.cancel();
          throw Exception('Compression cancelled by user');
        }
        rethrow;
      }
      
      // Ferma timer fallback
      fallbackTimer?.cancel();
      
      // Verifica se la task è stata cancellata prima di continuare
      if (taskId != null && _cancelledTasks.contains(taskId)) {
        DebugLogger.info('🛑 [Compression] Task $taskId cancellata, interrompo compressione');
        // Rimuovi il completer dalla mappa
        _activeCompleters.remove(taskId);
        throw Exception('Compression cancelled by user');
      }
      
      // Se il completer è stato completato con null (cancellazione), interrompi
      if (returnCode == null && taskId != null && _cancelledTasks.contains(taskId)) {
        DebugLogger.info('🛑 [Compression] Task $taskId cancellata (returnCode null), interrompo compressione');
        _activeCompleters.remove(taskId);
        throw Exception('Compression cancelled by user');
      }
      
      // Rimuovi il completer dalla mappa (non più necessario)
      if (taskId != null) {
        _activeCompleters.remove(taskId);
      }
      
      // Se il completer non è stato completato, prova a recuperare il return code direttamente
      ReturnCode? finalReturnCode = returnCode;
      if (finalReturnCode == null) {
        // Polling per aspettare che la sessione completi
        // Verifica periodicamente se la task è stata cancellata
        for (int i = 0; i < 100; i++) {
          // Verifica se la task è stata cancellata durante il polling
          if (taskId != null && _cancelledTasks.contains(taskId)) {
            _activeCompleters.remove(taskId);
            throw Exception('Compression cancelled by user');
          }
          
          await Future.delayed(const Duration(milliseconds: 100));
          final rc = await sessionRef.getReturnCode();
          if (rc != null) {
            finalReturnCode = rc;
            break;
          }
        }
      }
      
      // Verifica se la task è stata cancellata prima di recuperare output/errori
      if (taskId != null && _cancelledTasks.contains(taskId)) {
        _activeCompleters.remove(taskId);
        throw Exception('Compression cancelled by user');
      }
      
      // Ora recupera errori - prova più metodi per ottenere l'errore completo
      failStackTrace = await sessionRef.getFailStackTrace();
      
      // Se failStackTrace è vuoto, prova a ottenere tutti i log
      String? allLogs;
      if (failStackTrace == null || failStackTrace.isEmpty) {
        try {
          final logs = await sessionRef.getAllLogs();
          if (logs.isNotEmpty) {
            // Filtra solo i log di errore
            // getLevel() restituisce un int: 0=TRACE, 1=DEBUG, 2=INFO, 3=WARN, 4=ERROR, 5=FATAL
            final errorLogs = logs.where((log) {
              final level = log.getLevel();
              // ERROR = 4, FATAL = 5
              return level == 4 || level == 5;
            }).map((log) => log.getMessage()).where((msg) => msg.isNotEmpty).join('\n');
            
            if (errorLogs.isNotEmpty) {
              allLogs = errorLogs;
            } else {
              // Se non ci sono log di errore, prendi gli ultimi log
              final startIndex = logs.length > 10 ? logs.length - 10 : 0;
              final lastLogs = logs.sublist(startIndex).map((log) => log.getMessage()).where((msg) => msg.isNotEmpty).join('\n');
              if (lastLogs.isNotEmpty) {
                allLogs = lastLogs;
              }
            }
          }
        } catch (e) {
          DebugLogger.debug('⚠️ [Compression] Impossibile ottenere log: $e');
        }
      }
      
      // Usa allLogs se failStackTrace è vuoto
      final errorMessage = failStackTrace ?? allLogs ?? 'Unknown error (no error output available)';
      
      // Log dettagliato per debugging (sempre, non solo in debug mode)
      if (finalReturnCode == null || !finalReturnCode.isValueSuccess()) {
        DebugLogger.error('❌ [Compression] FFmpeg fallito');
        DebugLogger.error('   Return code: $finalReturnCode');
        DebugLogger.error('   Comando completo: $command');
        if (errorMessage.isNotEmpty && errorMessage != 'Unknown error (no error output available)') {
          final errorPreview = errorMessage.length > 1000 ? errorMessage.substring(0, 1000) + '...' : errorMessage;
          DebugLogger.error('   Errore completo: $errorPreview');
        } else {
          DebugLogger.error('   ⚠️ Nessun messaggio di errore disponibile da FFmpeg');
        }
        
        // Log dettagliato già fatto con DebugLogger sopra
      }
      
      if (finalReturnCode?.isValueSuccess() ?? false) {
        // Verifica se la task è stata cancellata prima di aggiornare il progresso
        final wasCancelled = taskId != null && _cancelledTasks.contains(taskId);
        if (!wasCancelled && onProgress != null) {
          onProgress(1.0, 'Compressing: 100.0%', totalFrames ?? 0);
        }
        
        final outputFile = File(outputPath);
        
        // IMPORTANTE: Attendi che il file sia effettivamente creato e abbia dimensione > 0
        // Su Android, il file potrebbe non essere ancora completamente scritto
        int retries = 0;
        const maxFileCheckRetries = 50; // 5 secondi totali (50 * 100ms)
        while (retries < maxFileCheckRetries) {
          if (await outputFile.exists()) {
            final outputSize = await outputFile.length();
            if (outputSize > 0) {
              // File esiste e ha dimensione > 0, procedi
              final endTime = DateTime.now();
              final duration = endTime.difference(startTime);
              final compressionRatio = ((1 - outputSize / inputSize) * 100).toStringAsFixed(1);

              // Log sempre per debugging (DebugLogger gestisce già kDebugMode)
              DebugLogger.info('✅ [Compression] Completata in ${duration.inSeconds}s - ${(inputSize / (1024 * 1024)).toStringAsFixed(2)}MB → ${(outputSize / (1024 * 1024)).toStringAsFixed(2)}MB ($compressionRatio% riduzione)');
              DebugLogger.debug('   File output: $outputPath');
              DebugLogger.debug('   Dimensione file: ${outputSize} bytes');

              // Cleanup sessioni FFmpeg per evitare blocchi nelle compressioni successive
              if (taskId != null) {
                _activeSessions.remove(taskId);
                _activeCompleters.remove(taskId);
                _cancelledTasks.remove(taskId);
              }

              return outputFile;
            }
          }
          // Attendi 100ms prima di riprovare
          await Future.delayed(const Duration(milliseconds: 100));
          retries++;
        }
        
        // Se arriviamo qui, il file non è stato creato o è vuoto
        DebugLogger.error('❌ [Compression] File output non creato o vuoto dopo $maxFileCheckRetries tentativi');
        DebugLogger.error('   Path atteso: $outputPath');
        DebugLogger.error('   Return code: $finalReturnCode');
        if (failStackTrace != null && failStackTrace.isNotEmpty) {
          DebugLogger.error('   Errore: ${failStackTrace.substring(0, failStackTrace.length > 500 ? 500 : failStackTrace.length)}');
        }
        throw Exception('Compressed file not created or empty');
      } else {
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        
        // Usa errorMessage invece di failStackTrace
        final errorMsg = failStackTrace ?? allLogs ?? 'Unknown error';
        
        // Verifica se l'errore è dovuto a VideoToolbox o encoder hardware
        bool shouldFallbackToSoftware = false;
        String? errorHint;
        
        if (errorMsg.contains('h264_videotoolbox') || 
            errorMsg.contains('VideoToolbox') ||
            errorMsg.contains('Option') && errorMsg.contains('not found') ||
            errorMsg.contains('Invalid argument') ||
            errorMsg.contains('Unrecognized option') ||
            errorMsg.contains('Unknown encoder') ||
            errorMsg.contains('encoder not found') ||
            errorMsg.contains('No such filter') ||
            (command.contains('h264_videotoolbox') && !command.contains('libx264'))) {
          
          // Se stiamo usando VideoToolbox e fallisce, prova fallback a software
          if (Platform.isMacOS && command.contains('h264_videotoolbox') && !command.contains('libx264')) {
            shouldFallbackToSoftware = true;
            errorHint = 'VideoToolbox fallito, provo fallback a software encoding (libx264)';
            DebugLogger.warning('⚠️ [Compression macOS] VideoToolbox fallito, provo fallback a libx264');
          } else if (Platform.isAndroid && command.contains('h264_mediacodec') && !command.contains('libx264')) {
            shouldFallbackToSoftware = true;
            errorHint = 'MediaCodec fallito, provo fallback a software encoding (libx264)';
            DebugLogger.warning('⚠️ [Compression Android] MediaCodec fallito, provo fallback a libx264');
          } else {
            errorHint = 'Possibile problema con encoder hardware o flag non supportati';
          }
        }
        
        // Se possiamo fare fallback, provalo
        if (shouldFallbackToSoftware && useHardware) {
          DebugLogger.info('🔄 [Compression] Retry con software encoding (libx264)');
          
          // Riprova con software encoding (ricorsivo, ma solo una volta)
          // Passa forceSoftwareEncoding=true per evitare loop infiniti
          try {
            DebugLogger.info('🔄 [Compression] Retry con software encoding (libx264) - forceSoftwareEncoding=true');
            return await compressVideo(
              inputFile: inputFile,
              settings: settings,
              onProgress: onProgress,
              totalFrames: totalFrames,
              taskId: taskId,
              originalMetadata: originalMetadata,
              forceSoftwareEncoding: true, // Forza software encoding per evitare loop
            );
          } catch (fallbackError) {
            // Se anche il fallback fallisce, lancia l'errore originale
            DebugLogger.error('❌ [Compression] Anche fallback a software encoding fallito: $fallbackError');
            // Continua e lancia l'errore originale
          }
        }
        
        // Log sempre gli errori
        DebugLogger.error('❌ [Compression] Fallita dopo ${duration.inSeconds}s');
        DebugLogger.error('   Return code: $finalReturnCode');
        DebugLogger.error('   Comando: $command');
        if (errorHint != null) {
          DebugLogger.error('   Hint: $errorHint');
        }
        if (errorMsg.isNotEmpty) {
          final errorPreview = errorMsg.length > 1000 ? errorMsg.substring(0, 1000) + '...' : errorMsg;
          DebugLogger.error('   Errore: $errorPreview');
        }
        
        DebugLogger.error('❌ [Compression] Fallita dopo ${duration.inSeconds}s: $errorMsg');
        if (errorHint != null) {
          DebugLogger.warning('   Hint: $errorHint');
        }
        throw Exception('FFmpeg compression failed: $errorMsg');
      }
    } catch (e) {
      // IMPORTANTE: Cleanup sessioni FFmpeg per evitare blocchi nelle compressioni successive
      if (taskId != null) {
        _activeSessions.remove(taskId);
        _cancelledTasks.remove(taskId);
        _activeCompleters.remove(taskId);
      }
      
      // Ferma timer fallback in caso di errore
      fallbackTimer?.cancel();
      
      // Log errore dettagliato (DebugLogger gestisce già kDebugMode)
      DebugLogger.error('❌ [Compression] Errore durante compressione: $e');
      DebugLogger.error('   Comando: ${command.substring(0, command.length > 200 ? 200 : command.length)}...');
      if (failStackTrace != null && failStackTrace!.isNotEmpty) {
        final stackPreview = failStackTrace!.length > 500 ? failStackTrace!.substring(0, 500) + '...' : failStackTrace!;
        DebugLogger.debug('   Stack trace: $stackPreview');
      }
      
      // Prova a cancellare la sessione FFmpeg se esiste ancora
      if (sessionRef != null) {
        try {
          await sessionRef.cancel();
        } catch (cancelError) {
          DebugLogger.warning('⚠️ [Compression] Errore durante cancellazione sessione: $cancelError');
        }
      }
      
      if (e is! Exception || !e.toString().contains('FFmpeg compression failed')) {
        // Se non è già un'eccezione FFmpeg, creane una
        throw Exception('FFmpeg compression failed: ${failStackTrace ?? e.toString()}');
      }
      rethrow;
    }
  }
  
  /// Cancella compressione per un task specifico
  static Future<void> cancelCompression(String taskId) async {
    // Marca la task come cancellata (per evitare retry e aggiornamenti progresso)
    _cancelledTasks.add(taskId);
    
    // Windows: cancella processo FFmpeg se presente
    if (Platform.isWindows) {
      await cancelCompressionWindows(taskId);
    }
    
    // Completa immediatamente il completer se esiste (per interrompere l'attesa)
    final completer = _activeCompleters[taskId];
    if (completer != null && !completer.isCompleted) {
      completer.complete(null); // Completa con null per indicare cancellazione
    }
    
    final session = _activeSessions[taskId];
    if (session != null) {
      try {
        // Cancella la sessione FFmpeg (ferma il processo)
        await session.cancel();
        
        // Prova anche a cancellare tutte le sessioni FFmpeg (metodo alternativo)
        try {
          FFmpegKit.cancel();
        } catch (e) {
          // Ignora errori se FFmpegKit.cancel() non disponibile
        }
      } catch (e) {
        DebugLogger.error('❌ [Compression] Errore durante cancellazione sessione: $e');
      }
      // NON rimuovere dalla mappa qui - verrà rimossa quando la sessione completa
      // Questo permette di fermare la sessione anche se viene chiamata più volte
    }
  }
  
  /// Cancella tutte le compressioni attive
  static Future<void> cancelAllCompressions() async {
    final taskIds = _activeSessions.keys.toList();
    for (final taskId in taskIds) {
      await cancelCompression(taskId);
    }
  }
  
  /// Build optimized FFmpeg compression command per video calcistici GoPro
  static String _buildOptimizedCompressionCommand({
    required String inputPath,
    required String outputPath,
    required CompressionSettings settings,
    Map<String, dynamic>? originalMetadata,
    bool forceSoftwareEncoding = false, // Forza software encoding anche se hardware disponibile
  }) {
    final buffer = StringBuffer();
    
    // Log level: usa "info" per avere output frame= e time= per progress tracking
    // Su Windows, abbiamo bisogno di vedere frame= per il progress tracking
    // Usa "info" che mostra frame= e time= ad ogni frame processato
    // NOTA: "verbose" potrebbe essere troppo verboso e rallentare, "warning" non mostra frame=
    if (Platform.isWindows) {
      buffer.write('-loglevel info -stats'); // -stats mostra frame= e time= più frequentemente
    } else {
      buffer.write('-loglevel info');
    }
    
    // Hardware acceleration per decoding (solo Windows, accelera anche il decoding)
    // Controlla impostazioni utente per abilitare/disabilitare
    if (Platform.isWindows && _supportsHardwareAcceleration()) {
      try {
        // Verifica se hardware decoding è abilitato nelle impostazioni
        // Usa import alias per evitare conflitti con parametro 'settings'
        if (settings_service.SettingsService.isInitialized && settings_service.SettingsService.getHardwareDecodingStatic()) {
          buffer.write(' -hwaccel d3d11va'); // DirectX 11 VA
          buffer.write(' -hwaccel_output_format d3d11'); // Output format per hardware decoding
        }
      } catch (e) {
        // Se SettingsService non disponibile, non usare hardware decoding
        DebugLogger.warning('⚠️ [Compression] Impossibile verificare impostazioni hardware decoding: $e');
      }
    }
    
    // Input file
    buffer.write(' -i "$inputPath"');
    
    // Rileva hardware acceleration e usa codec appropriato
    // Se forceSoftwareEncoding è true, forza software encoding
    final useHardware = forceSoftwareEncoding ? false : _supportsHardwareAcceleration();
    final videoCodec = _getVideoCodec(useHardware);
    buffer.write(' -c:v $videoCodec');
    
    // CRF (Constant Rate Factor) per qualità costante
    // IMPORTANTE: VideoToolbox NON supporta CRF, dobbiamo usare bitrate target
    // COMPATIBILITÀ: Tutti i video devono avere le stesse caratteristiche base per compatibilità cross-platform
    final crf = _getCRF(settings);
    
    if (useHardware) {
      if (Platform.isMacOS) {
        // VideoToolbox NON supporta -flags +global_header, quindi non lo aggiungiamo
        // VideoToolbox gestisce automaticamente gli header per compatibilità
        // VideoToolbox: NON supporta CRF, usa bitrate target
        // Calcola bitrate basato su risoluzione, framerate e qualità desiderata (CRF equivalente)
        final targetBitrate = _getTargetBitrate(settings, crf);
        buffer.write(' -b:v ${targetBitrate}k'); // Bitrate in kbps
        // macOS: VideoToolbox supporta hardware encoding nativamente
      } else if (Platform.isWindows) {
        // Windows hardware encoders (qsv/nvenc/amf): NON supportano CRF, usa bitrate target
        // Calcola bitrate basato su risoluzione, framerate e qualità desiderata (CRF equivalente)
        final targetBitrate = _getTargetBitrate(settings, crf);
        buffer.write(' -b:v ${targetBitrate}k'); // Bitrate in kbps
        
        // Flag globale per compatibilità streaming cross-platform (solo encoder hardware Windows)
        // +global_header: Aggiunge header globale al video (importante per streaming e compatibilità)
        // NOTA: Non usare con VideoToolbox (macOS) che non lo supporta
        buffer.write(' -flags +global_header');
        
        // Ottimizzazioni specifiche per encoder hardware Windows (velocità)
        // QSV: usa async_depth per parallelismo
        // NVENC: usa preset p1 (fastest) o p2 (faster) - già gestito da preset
        // AMF: usa quality speed per velocità
        // Aggiungiamo parametri specifici per velocità senza degradare qualità
        if (videoCodec == 'h264_qsv') {
          // Intel QSV: async_depth per parallelismo (velocizza encoding)
          buffer.write(' -async_depth 4'); // Parallelismo encoding (4 è un buon bilanciamento)
        } else if (videoCodec == 'h264_nvenc') {
          // NVIDIA NVENC: preset p1 (fastest) è già gestito, aggiungiamo lookahead=0 per velocità
          buffer.write(' -rc-lookahead 0'); // Disabilita lookahead per massima velocità
          buffer.write(' -surfaces 1'); // Riduce buffer per velocità
        } else if (videoCodec == 'h264_amf') {
          // AMD AMF: quality speed per velocità
          buffer.write(' -quality speed'); // Priorità velocità
        }
      } else {
        // Android MediaCodec: supporta CRF
        buffer.write(' -crf $crf');
      }
    } else {
      // Software encoding (libx264): usa CRF (supportato nativamente)
      buffer.write(' -crf $crf');
      
      // Flag globale per compatibilità streaming cross-platform (solo software encoding)
      // +global_header: Aggiunge header globale al video (importante per streaming e compatibilità)
      // NOTA: Non usare con VideoToolbox (macOS) che non lo supporta
      buffer.write(' -flags +global_header');
    }
    
    // Preset ottimizzato (fast con hardware, veryfast con software)
    final preset = _getPreset(useHardware);
    buffer.write(' -preset $preset');
    
    // Tune per movimento rapido (video sportivi) - COMPATIBILITÀ CROSS-PLATFORM
    // NOTA IMPORTANTE: VideoToolbox (macOS) NON supporta -tune, quindi non lo aggiungiamo
    // Per altri encoder:
    // - zerolatency: minimizza latenza (Windows hardware)
    // - film: ottimizzato per movimento (software encoding, Android)
    if (useHardware && Platform.isMacOS) {
      // VideoToolbox NON supporta -tune, quindi non aggiungiamo nulla
      // VideoToolbox ha ottimizzazioni automatiche per movimento
    } else if (Platform.isWindows && useHardware) {
      // Su Windows hardware encoding, zerolatency è necessario per velocità
      buffer.write(' -tune zerolatency');
    } else {
      // Software encoding (libx264): usa "film" per maggiore compatibilità
      buffer.write(' -tune film'); // Ottimizzato per movimento, alta compatibilità
    }
    
    // Ottimizzazioni aggiuntive per velocità (solo Windows hardware)
    if (Platform.isWindows && useHardware) {
      // Riduci B-frames per velocità (mantiene qualità ma velocizza encoding)
      // B-frames richiedono più calcolo, ridurli velocizza senza grande impatto qualità
      buffer.write(' -bf 2'); // 2 B-frames invece di default (più veloce, qualità ancora ottima)
    }
    
    // Profile e level H.264 - COMPATIBILITÀ CROSS-PLATFORM
    // Usa "main" profile invece di "high" per massima compatibilità:
    // - "baseline": massima compatibilità ma qualità inferiore (non usiamo)
    // - "main": ottimo compromesso qualità/compatibilità (supportato da tutti i dispositivi moderni)
    // - "high": migliore qualità ma può non essere supportato da dispositivi Android più vecchi
    // Level 4.0 supporta fino a 1080p 30fps ed è compatibile con tutti i dispositivi moderni
    // Level 4.1 supporta fino a 1080p 60fps ed è ancora molto compatibile
    // Level 4.2 supporta fino a 1440p 60fps ma può non essere supportato da alcuni dispositivi Android
    final targetResolution = settings.resolutionHeight ?? 1080;
    final targetFramerate = settings.framerate ?? 30.0;
    
    // Scegli level basato su risoluzione e framerate per massima compatibilità
    if (targetResolution <= 1080 && targetFramerate <= 30) {
      // 1080p 30fps: usa level 4.0 (massima compatibilità)
      buffer.write(' -profile:v main');
      buffer.write(' -level 4.0');
    } else if (targetResolution <= 1080 && targetFramerate <= 60) {
      // 1080p 60fps: usa level 4.1 (buona compatibilità)
      buffer.write(' -profile:v main');
      buffer.write(' -level 4.1');
    } else {
      // 1440p o superiore: usa level 4.2 (compatibile con dispositivi moderni)
      buffer.write(' -profile:v main');
      buffer.write(' -level 4.2');
    }
    
    // Resolution e framerate con scale algorithm ottimizzato per nitidezza
    // Per VideoToolbox: combiniamo scale e fps nel video filter per evitare conflitti con -vsync
    String? videoFilter;
    bool hasVideoFilter = false;
    
    if (settings.resolutionWidth != null && settings.resolutionHeight != null) {
      final scaleFilter = _getScaleFilter(
        settings.resolutionWidth!,
        settings.resolutionHeight!,
        useHardware,
      );
      
      // Se cambiamo framerate, aggiungiamo fps filter (compatibile con VideoToolbox)
      if (settings.framerate != null && useHardware) {
        // Per hardware: usa fps filter invece di -r per evitare conflitti con -vsync
        videoFilter = '$scaleFilter,fps=${settings.framerate}';
        hasVideoFilter = true;
      } else {
        videoFilter = scaleFilter;
        hasVideoFilter = true;
      }
      buffer.write(' -vf "$videoFilter"');
    } else if (settings.framerate != null && useHardware) {
      // Solo cambio framerate (senza cambio risoluzione) con hardware
      // Usa fps filter per evitare conflitti
      videoFilter = 'fps=${settings.framerate}';
      hasVideoFilter = true;
      buffer.write(' -vf "$videoFilter"');
    }
    
    // Framerate (solo per software encoding se non abbiamo già video filter)
    if (settings.framerate != null && !hasVideoFilter) {
      buffer.write(' -r ${settings.framerate}');
    }
    
    // VSync ottimizzato
    // Per VideoToolbox: se usiamo fps filter, usiamo passthrough (evita conflitti)
    // Per software: usiamo cfr quando cambiamo framerate, passthrough altrimenti
    if (useHardware) {
      // VideoToolbox: sempre passthrough quando usiamo video filter
      // Se non abbiamo video filter, passthrough è comunque sicuro
      buffer.write(' -vsync passthrough');
    } else if (settings.framerate != null) {
      // Software con cambio framerate: usa cfr (constant framerate)
      buffer.write(' -vsync cfr');
    } else {
      // Nessun cambio framerate: usa passthrough
      buffer.write(' -vsync passthrough');
    }
    
    // Threading (solo per software encoding)
    if (!useHardware) {
      buffer.write(' -threads 0'); // Usa tutti i core disponibili
    } else if (Platform.isWindows) {
      // Hardware encoding: alcuni encoder possono beneficiare di più thread per preprocessing
      // QSV può usare threads per preprocessing anche se encoding è hardware
      if (videoCodec == 'h264_qsv') {
        buffer.write(' -threads 0'); // Usa tutti i core per preprocessing QSV
      }
    }
    
    // Audio codec - COMPATIBILITÀ CROSS-PLATFORM
    // AAC è il codec audio standard supportato universalmente da:
    // - Android (ExoPlayer)
    // - iOS/macOS (AVPlayer)
    // - Windows (media_kit/mpv, Windows Media Player)
    // Bitrate 128k è un ottimo compromesso qualità/dimensione ed è supportato universalmente
    final audioCodec = _getAudioCodec(settings, originalMetadata);
    buffer.write(' -c:a $audioCodec');
    if (audioCodec != 'copy') {
      // Usa AAC-LC (Low Complexity) per massima compatibilità
      // Bitrate 128k è standard e supportato universalmente
      buffer.write(' -b:a 128k'); // Bitrate audio standard per compatibilità cross-platform
      buffer.write(' -ar 48000'); // Sample rate 48kHz (standard universale)
      buffer.write(' -ac 2'); // Stereo (2 canali) - supportato universalmente
    }
    
    // Movflags per MP4 streaming-friendly - COMPATIBILITÀ CROSS-PLATFORM
    // IMPORTANTE: faststart sposta i metadati all'inizio del file per streaming efficiente
    // Questo è cruciale per:
    // - ExoPlayer su Android (richiede metadati all'inizio)
    // - AVPlayer su macOS/iOS (ottimizza streaming)
    // - media_kit/mpv su Windows (migliora compatibilità)
    // NOTA: +empty_moov può causare problemi su alcuni player, quindi lo evitiamo
    // Usiamo solo +faststart che è universalmente supportato
    if (outputPath.toLowerCase().endsWith('.mp4')) {
      buffer.write(' -movflags +faststart'); // Solo faststart per massima compatibilità cross-platform
      // NOTA: -write_colr non è supportato universalmente da tutte le versioni di FFmpeg
      // Rimuoviamo questo flag per evitare errori "Unrecognized option"
    }
    
    // Output file
    buffer.write(' "$outputPath"');
    
    return buffer.toString();
  }
  
  /// Cache per rilevamento hardware (evita test multipli)
  static String? _cachedWindowsCodec;
  
  /// Verifica se hardware acceleration è disponibile
  /// Windows: rileva dinamicamente hardware disponibile (qsv/nvenc/amf) con fallback a libx264
  /// macOS: usa VideoToolbox (hardware acceleration)
  static bool _supportsHardwareAcceleration() {
    if (Platform.isWindows) {
      // Windows: rileva hardware dinamicamente (verrà testato durante la compressione)
      return true; // Prova hardware, fallback automatico a software se non disponibile
    }
    // Android: disabilita MediaCodec per stabilità (troppo lento/instabile)
    // Usa software encoding (libx264) che è più affidabile
    if (Platform.isAndroid) {
      return false; // Forza software encoding su Android
    }
    return Platform.isMacOS; // macOS usa hardware acceleration (VideoToolbox)
  }
  
  /// Ottiene codec video appropriato (hardware se disponibile)
  /// Windows: rileva hardware disponibile (qsv/nvenc/amf) con fallback a libx264
  /// macOS: usa VideoToolbox (hardware acceleration)
  static String _getVideoCodec(bool useHardware) {
    if (Platform.isWindows) {
      if (useHardware) {
        // Windows: prova hardware encoders in ordine di priorità
        // Usa cache se disponibile, altrimenti proverà durante la compressione
        if (_cachedWindowsCodec != null) {
          return _cachedWindowsCodec!;
        }
        // Ordine di priorità: Intel QSV (più comune) > NVIDIA NVENC > AMD VCE
        // Il test verrà fatto durante la compressione con fallback automatico
        return 'h264_qsv'; // Prova Intel Quick Sync Video per primo
      }
      return 'libx264'; // Software encoding fallback
    } else if (Platform.isMacOS) {
      return 'h264_videotoolbox'; // VideoToolbox (macOS)
    } else if (Platform.isAndroid) {
      // Android: usa sempre software encoding (libx264) per stabilità
      // MediaCodec è troppo lento e instabile su molti dispositivi
      return 'libx264'; // Software encoding (più stabile su Android)
    }
    return 'libx264'; // Fallback software
  }
  
  /// Rileva hardware encoder disponibile su Windows
  /// Prova h264_qsv, h264_nvenc, h264_amf in ordine
  /// Restituisce il primo disponibile o null se nessuno disponibile
  static Future<String?> _detectWindowsHardwareEncoder() async {
    // Se già in cache, usa quello
    if (_cachedWindowsCodec != null && _cachedWindowsCodec != 'libx264') {
      return _cachedWindowsCodec;
    }
    
    // Lista encoder da provare in ordine di priorità
    final encoders = ['h264_qsv', 'h264_nvenc', 'h264_amf'];
    
    for (final encoder in encoders) {
      try {
        // Test encoder con comando semplice
        final testCommand = [
          '-f', 'lavfi',
          '-i', 'testsrc=duration=1:size=320x240:rate=1',
          '-c:v', encoder,
          '-frames:v', '1',
          '-f', 'null',
          '-'
        ];
        
        final result = await Process.run('ffmpeg', testCommand).timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException('Encoder test timeout'),
        );
        
        // Se exit code è 0, l'encoder è disponibile
        if (result.exitCode == 0) {
          _cachedWindowsCodec = encoder;
          DebugLogger.info('✅ [Hardware] Rilevato encoder Windows: $encoder');
          return encoder;
        }
      } catch (e) {
        // Encoder non disponibile, prova il prossimo
        if (kDebugMode) {
          DebugLogger.debug('⚠️ [Hardware] Encoder $encoder non disponibile: $e');
        }
        continue;
      }
    }
    
    // Nessun hardware encoder disponibile
    _cachedWindowsCodec = 'libx264';
    if (kDebugMode) {
      DebugLogger.info('⚠️ [Hardware] Nessun hardware encoder disponibile, uso libx264');
    }
    return null;
  }
  
  /// Calcola CRF ottimale bilanciando qualità e dimensione file
  /// CRF più basso = qualità più alta ma file più grandi
  /// CRF 18-20: Alta qualità (per video sportivi)
  /// CRF 22-23: Buona qualità con buona compressione
  /// CRF 25+: Qualità media con alta compressione
  static int _getCRF(CompressionSettings settings) {
    final targetResolution = settings.resolutionHeight ?? 1080;
    final targetFramerate = settings.framerate ?? 30.0;
    
    // Per video sportivi: bilancia qualità e dimensione
    // CRF 20-22 offre ottimo compromesso qualità/dimensione per sport
    
    // Per 1080p 30fps: CRF 21 (alta qualità con buona compressione)
    if (targetResolution <= 1080 && targetFramerate <= 30) {
      return 21;
    }
    
    // Per 1440p 60fps: CRF 23 (buona qualità, bilanciato per movimento rapido e dimensione)
    if (targetResolution <= 1440 && targetFramerate <= 60) {
      return 23;
    }
    
    // Per 4K o superiore: CRF 24 (buona qualità con compressione più aggressiva)
    if (targetResolution > 1440) {
      return 24;
    }
    
    // Default: CRF 22 (bilanciato qualità/dimensione)
    return 22;
  }
  
  /// Ottiene preset ottimizzato bilanciando qualità e velocità
  /// Hardware: usa preset più lento per migliore qualità (fast/medium)
  /// Software: usa preset più veloce ma con buona qualità (fast/veryfast)
  static String _getPreset(bool useHardware) {
    if (Platform.isMacOS) {
      // VideoToolbox: preset limitati, "fast" offre buona qualità/velocità
      return 'fast'; // Bilanciato qualità/velocità per hardware
    } else if (Platform.isWindows) {
      if (useHardware) {
        // Hardware Windows: usa "veryfast" per massima velocità con qualità ancora ottima
        // Gli encoder hardware (QSV/NVENC/AMF) sono già molto veloci, "veryfast" non degrada significativamente la qualità
        return 'veryfast'; // Ottimizzato per velocità su hardware Windows
      } else {
        // Software Windows: usa "veryfast" per velocità (qualità ancora buona con CRF)
        return 'veryfast'; // Più veloce, qualità ancora ottima con CRF
      }
    } else if (Platform.isAndroid) {
      // Android: usa preset veloce per stabilità
      return 'veryfast'; // Più veloce, più stabile su Android
    } else {
      // Altro: usa preset veloce
      return 'fast'; // Bilanciato velocità/qualità
    }
  }
  
  /// Calcola bitrate target per VideoToolbox basato su risoluzione, framerate e qualità (CRF equivalente)
  /// VideoToolbox non supporta CRF, quindi dobbiamo usare bitrate target
  static int _getTargetBitrate(CompressionSettings settings, int crf) {
    final targetWidth = settings.resolutionWidth ?? 1920;
    final targetHeight = settings.resolutionHeight ?? 1080;
    final targetFramerate = settings.framerate ?? 30.0;
    
    // Calcola pixel totali
    final pixels = targetWidth * targetHeight;
    
    // Bitrate base basato su risoluzione e framerate
    // Formula approssimativa: bitrate = pixels * framerate * factor
    // Per 1080p 30fps: ~5000 kbps (alta qualità)
    // Per 1440p 60fps: ~12000 kbps (alta qualità)
    double baseBitrate;
    if (pixels <= 1920 * 1080) {
      // 1080p o inferiore
      baseBitrate = 5000.0; // 5 Mbps base per 1080p
    } else if (pixels <= 2560 * 1440) {
      // 1440p
      baseBitrate = 10000.0; // 10 Mbps base per 1440p
    } else {
      // 4K o superiore
      baseBitrate = 20000.0; // 20 Mbps base per 4K
    }
    
    // Aggiusta per framerate (60fps = 2x bitrate rispetto a 30fps)
    final framerateMultiplier = targetFramerate / 30.0;
    baseBitrate *= framerateMultiplier;
    
    // Aggiusta per qualità (CRF equivalente)
    // CRF più basso = bitrate più alto (migliore qualità)
    // CRF 18: ~1.5x, CRF 20: ~1.2x, CRF 23: ~1.0x, CRF 25: ~0.8x, CRF 28: ~0.6x
    double qualityMultiplier;
    if (crf <= 18) {
      qualityMultiplier = 1.5; // Alta qualità
    } else if (crf <= 20) {
      qualityMultiplier = 1.2; // Alta qualità (target per sport)
    } else if (crf <= 23) {
      qualityMultiplier = 1.0; // Buona qualità
    } else if (crf <= 25) {
      qualityMultiplier = 0.8; // Qualità media-alta
    } else if (crf <= 28) {
      qualityMultiplier = 0.6; // Qualità media
    } else {
      qualityMultiplier = 0.4; // Qualità bassa
    }
    
    final targetBitrate = (baseBitrate * qualityMultiplier).round();
    
    // Limiti ragionevoli
    const minBitrate = 2000; // 2 Mbps minimo
    const maxBitrate = 50000; // 50 Mbps massimo
    
    return targetBitrate.clamp(minBitrate, maxBitrate);
  }
  
  /// Ottiene scale filter ottimizzato per nitidezza
  static String _getScaleFilter(int targetWidth, int targetHeight, bool useHardware) {
    if (useHardware) {
      // Hardware può gestire lanczos senza problemi (migliore qualità)
      return 'scale=$targetWidth:$targetHeight:flags=lanczos';
    } else {
      // Software: bilinear per velocità (bilanciato)
      return 'scale=$targetWidth:$targetHeight:flags=bilinear';
    }
  }
  
  /// Ottiene audio codec (copy se possibile, altrimenti AAC)
  static String _getAudioCodec(CompressionSettings settings, Map<String, dynamic>? originalMetadata) {
    // Se framerate non cambia significativamente, copia audio (più veloce)
    final originalFramerate = originalMetadata?['framerate'] as double?;
    final targetFramerate = settings.framerate;
    
    if (targetFramerate == null || 
        (originalFramerate != null && 
         (targetFramerate - originalFramerate).abs() < 0.1)) {
      // Framerate simile: copia audio (più veloce, nessuna perdita)
      return 'copy';
    }
    
    // Framerate cambia: re-encode audio (necessario per sincronizzazione)
    return 'aac';
  }
  
  /// Estimate compressed file size
  static Future<int> estimateCompressedSize({
    required File inputFile,
    required CompressionSettings settings,
    Map<String, dynamic>? originalMetadata,
  }) async {
    if (settings.keepOriginal) {
      final originalSize = await inputFile.length();
      DebugLogger.debug('📊 [Stima] keepOriginal=true, restituisco dimensione originale: ${originalSize} bytes');
      return originalSize;
    }
    
    if (kDebugMode) {
      DebugLogger.debug('📊 [Stima] Calcolo stima compressa (keepOriginal=false)');
    }
    
    final originalSize = originalMetadata?['file_size'] as int? ?? await inputFile.length();
    
    // Usa metadata reali se disponibili, altrimenti fallback
    final originalWidth = originalMetadata?['width'] as int?;
    final originalHeight = originalMetadata?['height'] as int?;
    final originalFramerate = originalMetadata?['framerate'] as double?;
    
    // Se non abbiamo metadata, usa valori di default
    if (originalWidth == null || originalHeight == null) {
      // Fallback: stima conservativa basata solo su dimensione file
      return (originalSize * 0.7).round();
    }
    
    final originalArea = originalWidth * originalHeight;
    final targetArea = settings.resolutionWidth != null && settings.resolutionHeight != null
        ? settings.resolutionWidth! * settings.resolutionHeight!
        : originalArea;
    
    final areaRatio = targetArea / originalArea;
    
    // Calcola ratio framerate
    final targetFramerate = settings.framerate ?? originalFramerate ?? 30.0;
    final framerateRatio = originalFramerate != null && originalFramerate > 0
        ? targetFramerate / originalFramerate
        : 1.0;
    
    // Verifica se usiamo hardware acceleration (VideoToolbox)
    final useHardware = _supportsHardwareAcceleration();
    final crf = _getCRF(settings);
    
    int estimatedSize;
    
    if (useHardware && Platform.isMacOS) {
      // VideoToolbox: stima basata su bitrate target
      final targetBitrate = _getTargetBitrate(settings, crf); // kbps
      
      // Ottieni durata video (in secondi) dai metadata
      // La durata può essere int o double, quindi gestiamo entrambi i casi
      dynamic durationValue = originalMetadata?['duration'];
      double? duration;
      if (durationValue != null) {
        if (durationValue is int) {
          duration = durationValue.toDouble();
        } else if (durationValue is double) {
          duration = durationValue;
        } else if (durationValue is String) {
          duration = double.tryParse(durationValue);
        }
      }
      
      if (duration != null && duration > 0) {
        // Stima: bitrate (kbps) * durata (secondi) / 8 = dimensione in KB
        // Poi converti in bytes
        final videoSizeBytes = (targetBitrate * duration / 8 * 1024).round();
        
        // Aggiungi stima audio (128kbps è il nostro bitrate audio)
        final audioSizeBytes = (128 * duration / 8 * 1024).round();
        
        estimatedSize = videoSizeBytes + audioSizeBytes;
        
        DebugLogger.debug('📊 [Stima] VideoToolbox: bitrate=${targetBitrate}kbps, durata=${duration}s, stima=${estimatedSize} bytes');
      } else {
        // Fallback: stima basata su dimensione originale e bitrate
        // Calcola durata stimata dalla dimensione originale e bitrate originale
        final originalBitrate = originalMetadata?['bitrate'] as int?;
        if (originalBitrate != null && originalBitrate > 0) {
          // Usa bitrate originale reale se disponibile
          final sizeRatio = targetBitrate / (originalBitrate / 1000); // Converti bps in kbps
          estimatedSize = (originalSize * sizeRatio).round();
          
          if (kDebugMode) {
            DebugLogger.debug('📊 [Stima] VideoToolbox fallback (bitrate): bitrateOriginale=${originalBitrate}bps, bitrateTarget=${targetBitrate}kbps, stima=${estimatedSize} bytes');
          }
        } else {
          // Fallback finale: stima basata su bitrate tipico per risoluzione originale
          // Per video GoPro 2K 60fps: bitrate tipico ~50-80 Mbps
          // Per 1080p 30fps: bitrate tipico ~10-20 Mbps
          final originalPixels = (originalWidth ?? 1920) * (originalHeight ?? 1080);
          double estimatedOriginalBitrate;
          if (originalPixels <= 1920 * 1080) {
            estimatedOriginalBitrate = 15000; // 15 Mbps per 1080p
          } else if (originalPixels <= 2560 * 1440) {
            estimatedOriginalBitrate = 60000; // 60 Mbps per 1440p
          } else {
            estimatedOriginalBitrate = 100000; // 100 Mbps per 4K
          }
          
          final sizeRatio = targetBitrate / estimatedOriginalBitrate;
          estimatedSize = (originalSize * sizeRatio).round();
          
          if (kDebugMode) {
            DebugLogger.debug('📊 [Stima] VideoToolbox fallback (stima): bitrateOriginaleStimato=${estimatedOriginalBitrate}kbps, bitrateTarget=${targetBitrate}kbps, stima=${estimatedSize} bytes');
          }
        }
      }
    } else {
      // Software encoding o MediaCodec: stima basata su CRF
      // Fattore di compressione basato su CRF
      // CRF più basso = file più grandi (migliore qualità)
      // CRF 18: ~0.5-0.6, CRF 20: ~0.35-0.45, CRF 23: ~0.25-0.35, CRF 25: ~0.2-0.3, CRF 28: ~0.15-0.2
      double crfFactor;
      if (crf <= 18) {
        crfFactor = 0.55; // Alta qualità, file più grandi
      } else if (crf <= 20) {
        crfFactor = 0.40; // Alta qualità (target per sport)
      } else if (crf <= 23) {
        crfFactor = 0.30; // Buona qualità
      } else if (crf <= 25) {
        crfFactor = 0.25; // Qualità media-alta
      } else if (crf <= 28) {
        crfFactor = 0.18; // Qualità media
      } else {
        crfFactor = 0.12; // Qualità bassa
      }
      
      // Stima basata su area, framerate e CRF
      // Formula: originalSize * areaRatio * framerateRatio * crfFactor
      estimatedSize = (originalSize * areaRatio * framerateRatio * crfFactor).round();
    }
    
    return estimatedSize;
  }
  
  // Mappa per tenere traccia dei processi FFmpeg Windows attivi (per cancellazione)
  static final Map<String, Process> _activeWindowsProcesses = {};
  
  /// Compressione video su Windows usando FFmpeg tramite Process.run
  /// Supporta hardware acceleration (h264_qsv, h264_nvenc, h264_amf)
  static Future<File> _compressVideoWindows({
    required File inputFile,
    required String outputPath,
    required CompressionSettings settings,
    Function(double progress, String message, int processedFrames)? onProgress,
    int? totalFrames,
    String? taskId,
    Map<String, dynamic>? originalMetadata,
    required String command,
  }) async {
    // Verifica che FFmpeg sia disponibile
    // Se non trovato, lancia eccezione che verrà gestita dall'UI con messaggio di errore
    try {
      final ffmpegCheck = await Process.run('ffmpeg', ['-version']);
      if (ffmpegCheck.exitCode != 0) {
        throw FFmpegNotInstalledException();
      }
    } catch (e) {
      if (e is FFmpegNotInstalledException) {
        rethrow;
      }
      throw FFmpegNotInstalledException();
    }
    
    // Parse command in argomenti (gestisce path con spazi)
    var args = _parseFFmpegCommand(command);
    
    // Se usa hardware encoder, verifica disponibilità prima di procedere
    if (command.contains('-c:v h264_qsv') || 
        command.contains('-c:v h264_nvenc') || 
        command.contains('-c:v h264_amf')) {
      // Prova a rilevare hardware encoder disponibile
      final detectedEncoder = await _detectWindowsHardwareEncoder();
      if (detectedEncoder == null || detectedEncoder == 'libx264') {
        // Hardware non disponibile, fallback a software
        DebugLogger.info('⚠️ [Compression Windows] Hardware encoder non disponibile, fallback a libx264');
        // Ricostruisci comando con libx264 e CRF invece di bitrate
        final crf = _getCRF(settings);
        args = _parseFFmpegCommand(command.replaceAll(
          RegExp(r'-c:v (h264_qsv|h264_nvenc|h264_amf)'),
          '-c:v libx264'
        ).replaceAll(
          RegExp(r'-b:v \d+k'),
          '-crf $crf'
        ));
      } else {
        // Hardware disponibile, aggiorna codec se necessario
        if (!command.contains('-c:v $detectedEncoder')) {
          args = _parseFFmpegCommand(command.replaceAll(
            RegExp(r'-c:v (h264_qsv|h264_nvenc|h264_amf)'),
            '-c:v $detectedEncoder'
          ));
        }
      }
    }
    
    if (kDebugMode) {
      DebugLogger.debug('🎬 [Compression Windows] Esecuzione FFmpeg: ffmpeg ${args.join(" ")}');
    }
    
    // Log iniziale con informazioni dettagliate
    DebugLogger.info('🎬 [Compression Windows] Avvio compressione');
    DebugLogger.info('   Input: ${inputFile.path}');
    DebugLogger.info('   Output: $outputPath');
    DebugLogger.info('   Dimensione input: ${(await inputFile.length() / (1024 * 1024)).toStringAsFixed(2)} MB');
    DebugLogger.info('   Total frames: ${totalFrames ?? "N/A"}');
    DebugLogger.info('   Task ID: ${taskId ?? "N/A"}');
    DebugLogger.info('   Comando: ffmpeg ${args.join(" ")}');
    
    // Esegui FFmpeg con Process.start per poter leggere stderr in tempo reale
    final process = await Process.start('ffmpeg', args);
    
    DebugLogger.info('✅ [Compression Windows] Processo FFmpeg avviato (PID: ${process.pid})');
    
    // Salva il processo per permettere la cancellazione
    if (taskId != null) {
      _activeWindowsProcesses[taskId] = process;
    }
    
    // Verifica se la task è stata cancellata
    if (taskId != null && _cancelledTasks.contains(taskId)) {
      process.kill();
      throw Exception('Compression cancelled by user');
    }
    
    // Leggi stderr per progress tracking
    final stderrLines = <String>[];
    int lastFrameNumber = 0;
    String? lastTimeStr;
    final compressionStartTime = DateTime.now();
    int linesProcessed = 0;
    bool hasReceivedOutput = false;
    DateTime? lastOutputTime;
    
    // Usa UTF-8 decoder per Windows (più affidabile di SystemEncoding)
    process.stderr.transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter()).listen(
      (line) {
        stderrLines.add(line);
        linesProcessed++;
        hasReceivedOutput = true;
        lastOutputTime = DateTime.now();
        
        // Log le prime 10 linee per vedere cosa sta succedendo
        if (linesProcessed <= 10) {
          DebugLogger.info('📊 [Compression Windows] Linea $linesProcessed: ${line.length > 200 ? line.substring(0, 200) + "..." : line}');
        }
        
        // Log ogni 50 linee per debug (più frequente)
        if (linesProcessed % 50 == 0) {
          final logMessage = '📊 [Compression Windows] Linee processate: $linesProcessed, ultima linea: ${line.length > 100 ? line.substring(0, 100) + "..." : line}';
          DebugLogger.debug(logMessage);
        }
        
        if (onProgress == null) return;
        
        // Parse progress da stderr (formato FFmpeg: frame=  123 fps= 30 q=28.0 size=    1024kB time=00:00:04.12 bitrate=2032.0kbits/s)
        // Cerca sempre frame= PRIMA (più affidabile)
        final frameMatch = RegExp(r'frame=\s*(\d+)').firstMatch(line);
        
        if (frameMatch != null) {
          final frameNumber = int.tryParse(frameMatch.group(1) ?? '0') ?? 0;
          if (frameNumber > 0 && frameNumber > lastFrameNumber) {
            lastFrameNumber = frameNumber;
            
            // SEMPRE usa frame-based progress (più affidabile)
            if (totalFrames != null && totalFrames > 0) {
              // Progress basato su frame (metodo preferito)
              final progress = (frameNumber / totalFrames).clamp(0.0, 0.99);
              final progressPercent = (progress * 100).toStringAsFixed(1);
              onProgress(progress, 'Compressing: $progressPercent% (frame $frameNumber/$totalFrames)', frameNumber);
              
              // Log ogni 10 frame per debug (molto più frequente su Windows)
              if (frameNumber % 10 == 0 || frameNumber <= 5) {
                final logMessage = '🎬 [Compression Windows] Progress: $progressPercent% (frame $frameNumber/$totalFrames)';
                DebugLogger.info(logMessage);
              }
            } else {
              // Progress incrementale basato su frame (senza totalFrames)
              // Usa una stima più conservativa: progress minimo che aumenta gradualmente
              // Assumiamo almeno 1000 frame per video tipico, ma progress non supera 95% senza totalFrames
              final estimatedTotalFrames = 1000; // Stima conservativa
              final progress = (frameNumber / estimatedTotalFrames).clamp(0.01, 0.95);
              final progressPercent = (progress * 100).toStringAsFixed(1);
              onProgress(progress, 'Compressing: $progressPercent% (frame $frameNumber)', frameNumber);
              
              // Log ogni 10 frame per debug (più frequente)
              if (frameNumber % 10 == 0 || frameNumber <= 5) {
                final logMessage = '🎬 [Compression Windows] Progress incrementale: $progressPercent% (frame $frameNumber)';
                DebugLogger.info(logMessage);
              }
            }
          }
        } else {
          // Fallback: prova a parsare time= solo se non abbiamo trovato frame=
          // Ma preferiamo sempre frame= quando disponibile
          final timeMatch = RegExp(r'time=(\d{2}:\d{2}:\d{2}\.\d{2})').firstMatch(line);
          if (timeMatch != null) {
            final timeStr = timeMatch.group(1);
            if (timeStr != null && timeStr != lastTimeStr) {
              lastTimeStr = timeStr;
              
              // Parse tempo (HH:MM:SS.mm)
              final timeParts = timeStr.split(':');
              if (timeParts.length == 3) {
                final hours = int.tryParse(timeParts[0]) ?? 0;
                final minutes = int.tryParse(timeParts[1]) ?? 0;
                final secondsParts = timeParts[2].split('.');
                final seconds = int.tryParse(secondsParts[0]) ?? 0;
                final totalSeconds = hours * 3600 + minutes * 60 + seconds;
                
                // Se abbiamo totalFrames, stima frame da tempo (fallback se frame= non disponibile)
                if (totalFrames != null && totalFrames > 0) {
                  // Stima frame da tempo processato (assumendo framerate dai metadata o 30fps default)
                  final estimatedFramerate = originalMetadata?['framerate'] as double? ?? 30.0;
                  final estimatedFrames = (totalSeconds * estimatedFramerate).round();
                  final progress = (estimatedFrames / totalFrames).clamp(0.0, 0.99);
                  final progressPercent = (progress * 100).toStringAsFixed(1);
                  onProgress(progress, 'Compressing: $progressPercent% (time $timeStr)', estimatedFrames);
                  
                  if (kDebugMode && totalSeconds % 5 == 0) {
                    DebugLogger.debug('🎬 [Compression Windows] Progress (time-based): $progressPercent% (time $timeStr, frame stimato: $estimatedFrames/$totalFrames)');
                  }
                } else {
                  // Stima progress basato su tempo (solo se non abbiamo frame=)
                  final elapsed = DateTime.now().difference(compressionStartTime).inSeconds;
                  if (elapsed > 0 && totalSeconds > 0) {
                    // Stima: se abbiamo processato X secondi in Y secondi, il video totale sarà almeno X secondi
                    final estimatedTotalSeconds = totalSeconds + (totalSeconds * 0.1).round(); // Aggiungi 10% buffer
                    final progress = (totalSeconds / estimatedTotalSeconds).clamp(0.0, 0.95);
                    final progressPercent = (progress * 100).toStringAsFixed(1);
                    onProgress(progress, 'Compressing: $progressPercent% (time $timeStr)', 0);
                    
                    if (kDebugMode && totalSeconds % 5 == 0) {
                      DebugLogger.debug('🎬 [Compression Windows] Progress (time-based fallback): $progressPercent% (time $timeStr)');
                    }
                  }
                }
              }
            }
          } else if (kDebugMode && linesProcessed % 200 == 0) {
            // Log linee senza frame= o time= per debug (ogni 200 linee)
            DebugLogger.debug('⚠️ [Compression Windows] Linea senza frame/time: ${line.length > 80 ? line.substring(0, 80) + "..." : line}');
          }
        }
      },
      onError: (error) {
        DebugLogger.error('❌ [Compression Windows] Errore lettura stderr: $error');
      },
      onDone: () {
        final logMessage = '✅ [Compression Windows] Lettura stderr completata (totale linee: $linesProcessed, ultimo frame: $lastFrameNumber)';
        DebugLogger.info(logMessage);
      },
    );
    
    // Heartbeat: verifica ogni 5 secondi se il processo sta ancora funzionando
    Timer? heartbeatTimer;
    heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final elapsed = DateTime.now().difference(compressionStartTime).inSeconds;
      if (!hasReceivedOutput && elapsed > 10) {
        DebugLogger.warning('⚠️ [Compression Windows] Nessun output ricevuto dopo ${elapsed}s - processo potrebbe essere bloccato');
      } else if (lastOutputTime != null) {
        final timeSinceLastOutput = DateTime.now().difference(lastOutputTime!).inSeconds;
        if (timeSinceLastOutput > 30) {
          DebugLogger.warning('⚠️ [Compression Windows] Nessun output da ${timeSinceLastOutput}s - processo potrebbe essere bloccato');
        }
      }
      
      // Log stato corrente
      DebugLogger.debug('💓 [Compression Windows] Heartbeat: ${elapsed}s trascorsi, $linesProcessed linee, frame: $lastFrameNumber');
    });
    
    // Aspetta completamento con timeout
    DebugLogger.info('⏳ [Compression Windows] In attesa completamento processo...');
    
    // Timeout: se dopo 5 minuti non abbiamo ricevuto output, potrebbe essere bloccato
    final timeoutDuration = const Duration(minutes: 5);
    final exitCodeFuture = process.exitCode;
    
    // Verifica che il processo stia ancora funzionando
    Timer? timeoutTimer;
    timeoutTimer = Timer(timeoutDuration, () {
      if (!hasReceivedOutput) {
        DebugLogger.error('❌ [Compression Windows] TIMEOUT: Nessun output ricevuto dopo ${timeoutDuration.inMinutes} minuti');
        DebugLogger.error('   Il processo potrebbe essere bloccato. PID: ${process.pid}');
        // Non killiamo il processo qui, aspettiamo che termini naturalmente o che l'utente cancelli
      }
    });
    
    final exitCode = await exitCodeFuture;
    
    // Ferma timer
    timeoutTimer?.cancel();
    heartbeatTimer?.cancel();
    
    DebugLogger.info('🏁 [Compression Windows] Processo completato con exit code: $exitCode');
    DebugLogger.info('   Linee processate: $linesProcessed');
    DebugLogger.info('   Ultimo frame: $lastFrameNumber');
    DebugLogger.info('   Output ricevuto: $hasReceivedOutput');
    
    // Rimuovi processo dalla mappa
    if (taskId != null) {
      _activeWindowsProcesses.remove(taskId);
    }
    
    // Verifica se la task è stata cancellata
    if (taskId != null && _cancelledTasks.contains(taskId)) {
      throw Exception('Compression cancelled by user');
    }
    
    if (exitCode != 0) {
      final errorOutput = stderrLines.join('\n');
      
      // Log errore dettagliato per debugging
      DebugLogger.error('❌ [Compression Windows] FFmpeg fallito con exit code: $exitCode');
      DebugLogger.error('   Comando: ${command.substring(0, command.length > 200 ? 200 : command.length)}...');
      DebugLogger.error('   Linee stderr: ${stderrLines.length}');
      DebugLogger.error('   Output ricevuto: $hasReceivedOutput');
      DebugLogger.error('   Ultimo frame: $lastFrameNumber');
      if (stderrLines.isNotEmpty) {
        DebugLogger.error('   Ultime 10 linee stderr:');
        for (var i = stderrLines.length > 10 ? stderrLines.length - 10 : 0; i < stderrLines.length; i++) {
          DebugLogger.error('     ${i + 1}: ${stderrLines[i]}');
        }
      }
      DebugLogger.error('   Errore: ${errorOutput.length > 500 ? errorOutput.substring(0, 500) + "..." : errorOutput}');
      
      // Se errore hardware encoder, prova fallback a software
      if ((errorOutput.contains('Error creating a MFX session') ||
           errorOutput.contains('mfx implementation is not supported') ||
           errorOutput.contains('Could not open encoder') ||
           errorOutput.contains('Unknown encoder') ||
           errorOutput.contains('Invalid argument') ||
           errorOutput.contains('Option') && errorOutput.contains('not found')) &&
          command.contains('-c:v') && 
          !command.contains('-c:v libx264')) {
        DebugLogger.warning('⚠️ [Compression Windows] Hardware encoder fallito, provo fallback a libx264');
        
        // Fallback a software encoding
        final crf = _getCRF(settings);
        // Rimuovi flag problematici e sostituisci encoder
        var fallbackCommand = command.replaceAll(
          RegExp(r'-c:v (h264_qsv|h264_nvenc|h264_amf)'),
          '-c:v libx264'
        ).replaceAll(
          RegExp(r'-b:v \d+k'),
          '-crf $crf'
        );
        
        // Rimuovi flag specifici hardware che potrebbero causare problemi
        fallbackCommand = fallbackCommand.replaceAll(RegExp(r'-async_depth \d+'), '');
        fallbackCommand = fallbackCommand.replaceAll(RegExp(r'-rc-lookahead \d+'), '');
        fallbackCommand = fallbackCommand.replaceAll(RegExp(r'-surfaces \d+'), '');
        fallbackCommand = fallbackCommand.replaceAll(RegExp(r'-quality speed'), '');
        fallbackCommand = fallbackCommand.replaceAll(RegExp(r'-tune zerolatency'), '-tune film');
        
        // Aggiorna cache per non riprovare hardware
        _cachedWindowsCodec = 'libx264';
        
        DebugLogger.info('🔄 [Compression Windows] Retry con software encoding (libx264)');
        
        // Riprova con software encoding
        return await _compressVideoWindows(
          inputFile: inputFile,
          outputPath: outputPath,
          settings: settings,
          onProgress: onProgress,
          totalFrames: totalFrames,
          taskId: taskId,
          originalMetadata: originalMetadata,
          command: fallbackCommand,
        );
      }
      
      throw Exception('FFmpeg compression failed (exit code: $exitCode): $errorOutput');
    }
    
    // Aggiorna progress a 100%
    if (onProgress != null && totalFrames != null) {
      onProgress(1.0, 'Compressing: 100.0%', totalFrames);
    } else if (onProgress != null) {
      onProgress(1.0, 'Compressing: 100.0%', 0);
    }
    
    // Verifica che il file di output esista
    final outputFile = File(outputPath);
    if (!await outputFile.exists()) {
      throw Exception('File compresso non trovato: $outputPath');
    }
    
    return outputFile;
  }
  
  /// Parse FFmpeg command string in lista di argomenti
  /// Gestisce path con spazi tra virgolette
  static List<String> _parseFFmpegCommand(String command) {
    final args = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    
    for (int i = 0; i < command.length; i++) {
      final char = command[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ' ' && !inQuotes) {
        if (buffer.isNotEmpty) {
          args.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(char);
      }
    }
    
    if (buffer.isNotEmpty) {
      args.add(buffer.toString());
    }
    
    return args;
  }
  
  /// Cancella compressione Windows con kill aggressivo
  static Future<void> cancelCompressionWindows(String? taskId) async {
    if (taskId != null && _activeWindowsProcesses.containsKey(taskId)) {
      final process = _activeWindowsProcesses[taskId];
      if (process != null) {
        try {
          // Prova kill normale
          process.kill();
          
          // Attendi un momento per vedere se il processo termina
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Se il processo è ancora attivo, forza kill
          final exitCode = await process.exitCode.timeout(
            const Duration(seconds: 1),
            onTimeout: () {
              // Timeout = processo non termina, forza kill
              process.kill(ProcessSignal.sigkill);
              return -1;
            },
          );
          
          // Se exitCode è ancora in attesa, forza kill immediato
          if (exitCode == -1) {
            // Processo non risponde, forza kill
            try {
              process.kill(ProcessSignal.sigkill);
            } catch (e) {
              // Ignora errori se processo già terminato
            }
          }
        } catch (e) {
          // Se kill fallisce, prova a terminare tutti i processi FFmpeg
          try {
            if (Platform.isWindows) {
              // Su Windows, termina tutti i processi ffmpeg.exe
              await Process.run('taskkill', ['/F', '/IM', 'ffmpeg.exe', '/T']);
            }
          } catch (killError) {
            // Ignora errori se non ci sono processi FFmpeg
          }
        }
      }
      _activeWindowsProcesses.remove(taskId);
      DebugLogger.info('🛑 [Compression Windows] Processo FFmpeg cancellato per task: $taskId');
    }
  }
}

