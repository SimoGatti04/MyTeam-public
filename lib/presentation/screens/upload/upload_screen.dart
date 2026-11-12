import 'package:provider/provider.dart';
import '../../../core/services/updater/update_service.dart';
import '../../../core/services/updater/active_tasks_guard.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/file_validator.dart';
import '../../../core/constants/app_constants.dart';
import '../../widgets/folder_scan_dialog.dart';
import '../../widgets/multi_file_rename_dialog.dart';
import '../../../domain/entities/compression_settings.dart';
import '../../../domain/entities/upload_task.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/video_metadata_service.dart';
import '../../../core/services/ffmpeg_installation_service.dart';
import '../../../features/upload/services/video_compression_service.dart';
import '../widgets/compression_settings_widget.dart';
import '../widgets/upload_progress_widget.dart';
import '../widgets/video_info_widget.dart';
import '../../../features/upload/viewmodels/upload_viewmodel.dart';
import '../../../data/repositories/upload_repository_impl.dart';
import '../../../data/datasources/remote/upload_remote_datasource.dart';
import '../../../data/datasources/local/upload_local_datasource.dart';
import '../../../core/network/api_client.dart';
import '../../../domain/usecases/upload_video_usecase.dart';
import '../../../core/services/debug_logger.dart';

/// Upload screen - Presentation layer
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> with WidgetsBindingObserver {
  File? _selectedVideo;
  Map<String, dynamic>? _videoMetadata;
  int? _estimatedCompressedSize;
  bool _isCalculatingSize = false;
  CompressionSettings _compressionSettings = const CompressionSettings(keepOriginal: true);
  bool _isProcessing = false;
  bool _isCompressing = false;
  double _progress = 0.0;
  double _compressionProgress = 0.0;
  String? _statusMessage;
  String? _compressionStatusMessage;
  UploadViewModel? _viewModel;
  bool _hasProviderError = false;
  bool _isInitialized = false;
  int _buildCounter = 0; // Contatore per forzare ricostruzione
  late TextEditingController _titleController; // Controller per campo titolo
  DateTime? _recordedDate; // Data registrazione video

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _titleController = TextEditingController();
    // Su Windows, controlla FFmpeg all'apertura della schermata
    if (Platform.isWindows) {
      // Attendi che il widget sia montato prima di mostrare il dialog
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkFFmpegOnWindows();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewModel?.removeListener(_onViewModelChanged);
    _titleController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _isInitialized) {
      _reloadTasks();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupSharedViewModel();
  }

  void _setupSharedViewModel() {
    UploadViewModel? providerVm;
    try {
      providerVm = Provider.of<UploadViewModel>(context, listen: false);
    } catch (_) {
      providerVm = null;
    }

    if (providerVm == null) {
      DebugLogger.error('UploadScreen: Provider<UploadViewModel> non disponibile nel widget tree!');
      if (mounted) {
        setState(() {
          _hasProviderError = true;
          _isInitialized = false;
        });
      }
      return;
    }

    if (_viewModel != providerVm) {
      _viewModel?.removeListener(_onViewModelChanged);
      _viewModel = providerVm;
      _viewModel!.addListener(_onViewModelChanged);
      UpdateService.instance.setGuard(ActiveTasksGuard(uploadViewModel: _viewModel));
    }

    if (!_isInitialized) {
      _reloadTasks();
    }
  }

  @override
  void didUpdateWidget(UploadScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isInitialized) {
      _reloadTasks();
    }
  }

  void _reloadTasks() {
    final vm = _viewModel;
    if (vm == null) return;

    vm.removeListener(_onViewModelChanged);
    vm.addListener(_onViewModelChanged);

    vm.loadSavedUploadTasks().then((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _progress = vm.uploadProgress;
          _compressionProgress = vm.compressionProgress;
          _statusMessage = vm.uploadStatusMessage;
          _compressionStatusMessage = vm.compressionStatusMessage;
          _isProcessing = vm.isUploading;
          _isCompressing = vm.isCompressing;
        });
      }
    });
  }

  void _onViewModelChanged() {
    if (!mounted || _viewModel == null) return;
    final vm = _viewModel!;

    setState(() {
      _progress = vm.uploadProgress;
      _compressionProgress = vm.compressionProgress;
      _statusMessage = vm.uploadStatusMessage;
      _compressionStatusMessage = vm.compressionStatusMessage;
      _isProcessing = vm.isUploading;
      _isCompressing = vm.isCompressing;
    });
  }

  @override
  Widget build(BuildContext context) {
    _buildCounter++;

    if (_hasProviderError || _viewModel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Upload Video')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Servizio di caricamento non disponibile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Impossibile collegare l\'istanza condivisa di UploadViewModel. L\'aggiornamento dell\'app rimane bloccato per sicurezza.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _setupSharedViewModel(),
                  child: const Text('Riprova connessione'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Video'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // File selection
            _buildFileSelection(),
            const SizedBox(height: 24),

            // Video Title (editabile prima upload)
            if (_selectedVideo != null) ...[
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Video Title',
                  hintText: 'Enter video title',
                  border: OutlineInputBorder(),
                  helperText: 'Leave empty to use filename',
                ),
                maxLength: 255,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 24),

              // Data registrazione
              InkWell(
                onTap: () => _selectRecordedDate(),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Data Registrazione',
                    hintText: _recordedDate == null
                        ? 'Seleziona data (opzionale)'
                        : _formatDate(_recordedDate!),
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.calendar_today),
                    helperText: 'Data in cui è stato registrato il video',
                  ),
                  child: Text(
                    _recordedDate == null
                        ? ''
                        : _formatDate(_recordedDate!),
                    style: TextStyle(
                      color: _recordedDate == null
                          ? Colors.grey
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
              if (_recordedDate != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _recordedDate = null;
                    });
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Rimuovi data'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],

            // Video Info Widget (mostra metadata e dimensione prevista)
            if (_selectedVideo != null && _videoMetadata != null) ...[
              VideoInfoWidget(
                metadata: _videoMetadata,
                estimatedSize: _estimatedCompressedSize,
                isLoading: _isCalculatingSize,
              ),
              const SizedBox(height: 24),
            ],

            // Compression settings
            if (_selectedVideo != null) ...[
              CompressionSettingsWidget(
                settings: _compressionSettings,
                onSettingsChanged: (settings) {
                  setState(() {
                    _compressionSettings = settings;
                  });
                  // Ricalcola dimensione prevista quando cambiano le impostazioni
                  _updateEstimatedSize();
                },
              ),
              const SizedBox(height: 24),
            ],

            // Upload button
            if (_selectedVideo != null) ...[
              ElevatedButton(
                onPressed: (_isProcessing || _isCompressing) ? null : _handleUpload,
                child: const Text('Upload Video'),
              ),
              const SizedBox(height: 16),
            ],

            // Upload in corso (sequenziale - mostra solo task corrente)
            if (_isInitialized && _viewModel!.currentUploadTask != null) ...[
              _buildActiveUploads(),
              const SizedBox(height: 16),
            ],

            // Pulsanti di controllo
            if (_isInitialized && (_viewModel!.currentUploadTask != null ||
                _viewModel!.uploadTasks.any((task) =>
                  task.status == UploadStatus.completed ||
                  task.status == UploadStatus.cancelled ||
                  task.status == UploadStatus.error
                ))) ...[
              Row(
                children: [
                  // Pulsante annulla task corrente
                  if (_viewModel!.currentUploadTask != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _handleCancelCurrent(),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Annulla Task'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  if (_viewModel!.currentUploadTask != null) const SizedBox(width: 8),
                  // Pulsante pulizia task completate
                  if (_viewModel!.uploadTasks.any((task) =>
                    task.status == UploadStatus.completed ||
                    task.status == UploadStatus.cancelled ||
                    task.status == UploadStatus.error
                  ))
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _handleClearCompleted(),
                        icon: const Icon(Icons.delete_sweep),
                        label: const Text('Pulisci Completate'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Upload completati (da persistenza)
            if (_isInitialized && _viewModel!.uploadTasks.any(
              (task) => task.status == UploadStatus.completed
            ))
              _buildCompletedUploads(),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select Videos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_selectedVideo == null)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _pickMultipleVideos,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.video_library),
                      label: Text(_isProcessing ? 'Caricamento...' : 'Select Files'),
                    ),
                  ),
                  // Mostra pulsante "Select Folder" solo su Windows/macOS (non supportato su Android)
                  if (Platform.isWindows || Platform.isMacOS) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : _pickFolder,
                        icon: const Icon(Icons.folder),
                        label: const Text('Select Folder'),
                      ),
                    ),
                  ],
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected: ${_selectedVideo!.path.split(Platform.pathSeparator).last}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Size: ${_formatFileSize(_selectedVideo!.lengthSync())}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _isProcessing ? null : () {
                      setState(() {
                        _selectedVideo = null;
                        _videoMetadata = null;
                        _estimatedCompressedSize = null;
                        _titleController.clear(); // Pulisci campo titolo
                      });
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Remove'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Seleziona uno o più file video contemporaneamente
  Future<void> _pickMultipleVideos() async {
    if (_isProcessing) {
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
        withData: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // Valida e filtra file
      final validFiles = <File>[];
      final invalidFiles = <String, String>{}; // path -> error message

      for (final pickedFile in result.files) {
        if (pickedFile.path == null) {
          continue;
        }

        try {
          final file = File(pickedFile.path!);

          // Verifica file esiste e è accessibile
          if (!await file.exists()) {
            invalidFiles[pickedFile.path!] = 'File non esiste';
            continue;
          }

          // Valida file
          final validation = await FileValidator.validateFile(file);
          if (validation.isValid) {
            validFiles.add(file);
          } else {
            invalidFiles[pickedFile.path!] = validation.error ?? 'File non valido';
          }
        } catch (e) {
          invalidFiles[pickedFile.path ?? 'unknown'] = 'Errore accesso file: $e';
        }
      }

      setState(() {
        _isProcessing = false;
      });

      // Mostra risultati validazione
      if (invalidFiles.isNotEmpty) {
        final invalidCount = invalidFiles.length;
        final validCount = validFiles.length;
        _showError('$invalidCount file ignorati (formato non supportato o invalido). $validCount file validi selezionati.');
      }

      // Verifica limite file
      if (validFiles.length > AppConstants.maxFilesPerBatch) {
        _showError('Troppi file selezionati (${validFiles.length}). Massimo: ${AppConstants.maxFilesPerBatch}');
        return;
      }

      if (validFiles.isEmpty) {
        _showError('Nessun file video valido selezionato');
        return;
      }

      // Se è un solo file, mostra UI per modificare titolo prima dell'upload
      if (validFiles.length == 1) {
        // Gestisci come file singolo con UI completa
        final file = validFiles.first;
        await _handleSingleFileSelection(file);
      } else {
        // Avvia upload multipli direttamente
        await _startMultipleUploads(validFiles);
      }

    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showError('Errore durante selezione file: $e');
    }
  }

  /// Gestisce selezione file singolo con UI completa (titolo modificabile, metadata, ecc.)
  Future<void> _handleSingleFileSelection(File videoFile) async {
    try {
      // Estrai metadata con timeout
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lettura metadati video...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      try {
        final metadata = await VideoMetadataService.extractMetadata(videoFile.path)
            .timeout(const Duration(seconds: 30), onTimeout: () {
          throw TimeoutException('Estrazione metadata timeout');
        });

        // Estrai nome file per pre-compilare titolo
        final videoName = videoFile.path.split(Platform.pathSeparator).last;
        // Rimuovi estensione per titolo più pulito
        final titleWithoutExtension = videoName.replaceAll(RegExp(r'\.[^.]*$'), '');

        setState(() {
          _selectedVideo = videoFile;
          _videoMetadata = metadata;
          _estimatedCompressedSize = null;
          _isProcessing = false;
          // Pre-compila titolo con nome file (senza estensione)
          _titleController.text = titleWithoutExtension;
        });

        // Calcola dimensione prevista dopo aver estratto metadata
        _updateEstimatedSize();
      } catch (e) {
        // Gestisci errore estrazione metadata
        if (e is FFmpegNotInstalledException) {
          // FFmpeg non installato: mostra dialog
          if (mounted) {
            await _showFFmpegInstallationDialog();
          }
          setState(() {
            _isProcessing = false;
          });
          return;
        }

        // Se fallisce estrazione metadata, continua comunque (metadata opzionali)
        DebugLogger.warning('⚠️ [FilePicker] Estrazione metadata fallita: $e');

        final videoName = videoFile.path.split(Platform.pathSeparator).last;
        final titleWithoutExtension = videoName.replaceAll(RegExp(r'\.[^.]*$'), '');

        setState(() {
          _selectedVideo = videoFile;
          _videoMetadata = null;
          _estimatedCompressedSize = null;
          _isProcessing = false;
          _titleController.text = titleWithoutExtension;
        });
      }
    } catch (e) {
      _showError('Errore durante preparazione file: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  /// Seleziona cartella e scansiona file video
  Future<void> _pickFolder() async {
    if (_isProcessing) {
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
      });

      // Seleziona cartella (solo su Windows/macOS, non supportato su Android)
      String? folderPath;
      if (Platform.isWindows || Platform.isMacOS) {
        folderPath = await FilePicker.platform.getDirectoryPath();
      } else {
        // Su Android, usa file picker con allowMultiple come fallback
        _showError('Selezione cartella non supportata su Android. Usa "Select Files" invece.');
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      if (folderPath == null) {
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // Mostra dialog di scanning e scansiona cartella
      List<File>? validFilesResult;

      validFilesResult = await showDialog<List<File>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => FolderScanDialog(
          folderPath: folderPath!, // folderPath è già verificato sopra (non null)
          onComplete: (files) {
            Navigator.of(context).pop(files);
          },
          onCancel: () {
            Navigator.of(context).pop(null);
          },
        ),
      );

      if (validFilesResult == null) {
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      final validFiles = validFilesResult;

      setState(() {
        _isProcessing = false;
      });

      if (validFiles.isEmpty) {
        _showError('Nessun file video valido trovato nella cartella');
        return;
      }

      // Verifica limite file
      if (validFiles.length > AppConstants.maxFilesPerBatch) {
        _showError('Troppi file trovati (${validFiles.length}). Massimo: ${AppConstants.maxFilesPerBatch}. Verranno caricati solo i primi ${AppConstants.maxFilesPerBatch}');
        await _startMultipleUploads(validFiles.take(AppConstants.maxFilesPerBatch).toList());
      } else {
        await _startMultipleUploads(validFiles);
      }

    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showError('Errore durante scansione cartella: $e');
    }
  }

  /// Avvia upload multipli
  Future<void> _startMultipleUploads(List<File> files) async {
    if (files.isEmpty) {
      return;
    }

    // Mostra dialog per modificare titoli e impostazioni compressione
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => MultiFileRenameDialog(
        files: files,
        compressionSettings: _compressionSettings,
      ),
    );

    // Se l'utente ha annullato, non avviare upload
    if (result == null) {
      return;
    }

    // Estrai titoli e impostazioni di compressione
    final modifiedTitles = result['titles'] as Map<int, String>;
    final compressionSettings = result['compressionSettings'] as CompressionSettings;

    // Aggiorna impostazioni globali
    setState(() {
      _compressionSettings = compressionSettings;
    });

    // Aggiungi tutti i file alla coda di upload sequenziali
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final fileName = file.path.split(Platform.pathSeparator).last;
      final titleWithoutExtension = fileName.replaceAll(RegExp(r'\.[^.]*$'), '');

      // Usa titolo modificato se presente, altrimenti usa nome file
      final title = modifiedTitles[i] ?? titleWithoutExtension;

      // Aggiungi alla coda (verrà processato sequenzialmente)
      _viewModel!.queueUpload(
        videoFile: file,
        title: title,
        compressionSettings: compressionSettings,
      );
    }

    // Mostra messaggio
    if (files.length == 1) {
      _showSuccess('File aggiunto alla coda di upload');
    } else {
      _showSuccess('${files.length} file aggiunti alla coda di upload');
    }
  }

  Future<void> _pickVideo() async {
    // Evita doppia selezione
    if (_isProcessing) {
      return;
    }

    try {
      // Mostra loading durante la selezione
      setState(() {
        _isProcessing = true;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: false, // Non leggere bytes direttamente (lento per file grandi)
      );

      // Reset processing state prima di gestire il risultato
      if (result == null || result.files.isEmpty) {
        // Utente ha annullato la selezione
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      final pickedFile = result.files.single;

      if (pickedFile.path == null) {
        _showError('Impossibile accedere al file selezionato.');
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // Normalizza path per Windows (gestisce backslash e caratteri speciali)
      String filePath = pickedFile.path!;
      if (Platform.isWindows) {
        // Windows: normalizza separatori e gestisce path con spazi
        filePath = filePath.replaceAll('\\', '/'); // Normalizza separatori
        // Rimuovi eventuali prefissi problematici
        if (filePath.startsWith('file:///')) {
          filePath = filePath.substring(7); // Rimuovi "file:///"
        } else if (filePath.startsWith('file://')) {
          filePath = filePath.substring(7); // Rimuovi "file://"
        }
        // Windows può avere path come "C:/Users/..." o "C:\Users\..."
        // File() gestisce entrambi, ma normalizziamo per sicurezza
      }

      File? videoFile = File(filePath);

      // Su Android, i file da cloud storage (OneDrive, Google Drive) potrebbero non essere immediatamente accessibili
      // Su Windows, i file potrebbero avere problemi di permessi o path
      bool fileAccessible = false;
      try {
        // Verifica esistenza file
        fileAccessible = await videoFile.exists();

        if (!fileAccessible) {
          DebugLogger.warning('⚠️ [FilePicker] File non esiste: $filePath');
          // Su Windows, prova a normalizzare ulteriormente il path
          if (Platform.isWindows) {
            // Prova con path assoluto
            final absolutePath = Uri.file(filePath).toFilePath(windows: true);
            final absoluteFile = File(absolutePath);
            fileAccessible = await absoluteFile.exists();
            if (fileAccessible) {
              videoFile = absoluteFile;
              DebugLogger.info('✅ [FilePicker] File trovato con path assoluto: $absolutePath');
            }
          }
        }

        if (fileAccessible) {
          // Prova a leggere il file per verificare che sia accessibile
          // Su Windows, usa openRead invece di readAsBytes per file grandi
          // Usa timeout breve per non bloccare se il file è su cloud storage
          try {
            final stream = videoFile.openRead();
            // Leggi il primo chunk per verificare che il file sia accessibile
            await stream.first.timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                throw TimeoutException('File non ancora scaricato da cloud storage o non accessibile');
              },
            );
            // Lo stream viene chiuso automaticamente quando viene consumato
            fileAccessible = true;
          } catch (e) {
            if (e is TimeoutException) {
              rethrow;
            }
            // Altro errore di lettura, prova con metodo alternativo
            DebugLogger.warning('⚠️ [FilePicker] Errore lettura file, provo metodo alternativo: $e');
            // Su Windows, alcuni file potrebbero richiedere permessi speciali
            // Prova a verificare solo l'esistenza e dimensione
            final fileSize = await videoFile.length();
            if (fileSize > 0) {
              fileAccessible = true;
              DebugLogger.info('✅ [FilePicker] File accessibile (dimensione: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB)');
            } else {
              throw Exception('File vuoto o non accessibile');
            }
          }
        }
      } catch (e) {
        if (e is TimeoutException ||
            e.toString().contains('cloud') ||
            e.toString().contains('OneDrive') ||
            e.toString().contains('not available') ||
            e.toString().contains('not accessible')) {
          // File su cloud storage o non accessibile, deve essere scaricato/copiato
          DebugLogger.warning('⚠️ [FilePicker] File su cloud storage o non accessibile, copia in cache: $e');

          // Su Windows, anche i file locali potrebbero avere problemi di accesso
          // Copia sempre in cache per sicurezza
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Preparazione file in corso...\n${pickedFile.name}\nQuesto potrebbe richiedere alcuni minuti per file grandi.'),
                duration: const Duration(minutes: 10), // Timeout lungo per file grandi
                action: SnackBarAction(
                  label: 'Annulla',
                  onPressed: () {
                    setState(() {
                      _isProcessing = false;
                    });
                  },
                ),
              ),
            );
          }

          // Copia file in cache locale (forza download da cloud storage o risolve problemi di accesso)
          videoFile = await _copyFileFromCloudStorage(pickedFile);
          if (videoFile == null) {
            _showError('Impossibile accedere al file. Verifica i permessi e riprova.');
            setState(() {
              _isProcessing = false;
            });
            return;
          }
          fileAccessible = true;
        } else {
          // Altro errore
          if (kDebugMode) {
            DebugLogger.error('⚠️ [FilePicker] Errore accesso file: $e');
            DebugLogger.debug('   Path originale: ${pickedFile.path}');
            DebugLogger.debug('   Path normalizzato: $filePath');
          }
          fileAccessible = false;
        }
      }

      if (!fileAccessible || videoFile == null) {
        _showError('File non accessibile. Riprova.');
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // Estrai metadata con timeout
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lettura metadati video...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      try {
        final metadata = await VideoMetadataService.extractMetadata(videoFile.path)
            .timeout(const Duration(seconds: 30), onTimeout: () {
          throw TimeoutException('Estrazione metadata timeout');
        });

        // Estrai nome file per pre-compilare titolo
        final videoName = videoFile.path.split(Platform.pathSeparator).last;
        // Rimuovi estensione per titolo più pulito
        final titleWithoutExtension = videoName.replaceAll(RegExp(r'\.[^.]*$'), '');

        setState(() {
          _selectedVideo = videoFile;
          _videoMetadata = metadata;
          _estimatedCompressedSize = null;
          _isProcessing = false;
          // Pre-compila titolo con nome file (senza estensione)
          _titleController.text = titleWithoutExtension;
        });

        // Calcola dimensione prevista dopo aver estratto metadata
        _updateEstimatedSize();
      } catch (e) {
        // Gestisci errore estrazione metadata
        DebugLogger.warning('⚠️ [FilePicker] Errore estrazione metadata: $e');

        // Estrai nome file per pre-compilare titolo
        final videoName = videoFile.path.split(Platform.pathSeparator).last;
        // Rimuovi estensione per titolo più pulito
        final titleWithoutExtension = videoName.replaceAll(RegExp(r'\.[^.]*$'), '');

        setState(() {
          _selectedVideo = videoFile;
          _videoMetadata = null;
          _estimatedCompressedSize = null;
          _isProcessing = false;
          // Pre-compila titolo con nome file (senza estensione)
          _titleController.text = titleWithoutExtension;
        });

        if (e is TimeoutException) {
          _showError('Timeout durante la lettura dei metadati. Il file verrà comunque caricato.');
        } else {
          _showError('Impossibile leggere i metadati del video. Il file verrà comunque caricato.');
        }
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      DebugLogger.error('❌ [FilePicker] Errore durante selezione: $e');

      _showError('Errore durante la selezione del file: $e');
    }
  }

  /// Copia file da cloud storage in cache locale (forza download)
  /// Necessario per file OneDrive/Google Drive su Android che non sono immediatamente accessibili
  /// Su Windows, risolve anche problemi di accesso ai file locali
  Future<File?> _copyFileFromCloudStorage(PlatformFile pickedFile) async {
    try {
      DebugLogger.info('📥 [FilePicker] Copia file in cache: ${pickedFile.name} (${(pickedFile.size / (1024 * 1024)).toStringAsFixed(2)} MB)');

      final tempDir = await getTemporaryDirectory();

      // Normalizza nome file per Windows (rimuovi caratteri non validi)
      String safeFileName = pickedFile.name;
      if (Platform.isWindows) {
        // Windows non permette: < > : " / \ | ? *
        safeFileName = safeFileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      }

      final cacheFile = File('${tempDir.path}/$safeFileName');

      // Se il file esiste già in cache, rimuovilo
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }

      // Normalizza path sorgente per Windows
      String sourcePath = pickedFile.path!;
      if (Platform.isWindows) {
        sourcePath = sourcePath.replaceAll('\\', '/');
        if (sourcePath.startsWith('file:///')) {
          sourcePath = sourcePath.substring(7);
        } else if (sourcePath.startsWith('file://')) {
          sourcePath = sourcePath.substring(7);
        }
      }

      // Copia file da path originale a cache locale
      // Questo forza il download da cloud storage se necessario
      // Su Windows, risolve problemi di accesso ai file
      final sourceFile = File(sourcePath);

      // Usa stream per file grandi (evita problemi di memoria)
      final inputStream = sourceFile.openRead();
      final outputStream = cacheFile.openWrite();

      int totalBytes = 0;
      final fileSize = pickedFile.size;

      try {
        // Leggi e scrivi in chunk per mostrare progresso
        await for (final chunk in inputStream) {
          outputStream.add(chunk);
          totalBytes += chunk.length;

          // Aggiorna messaggio ogni 10MB
          if (fileSize > 0 && totalBytes % (10 * 1024 * 1024) < chunk.length) {
            final progress = (totalBytes / fileSize * 100).toStringAsFixed(1);
            if (mounted) {
              DebugLogger.debug('📥 [FilePicker] Download progress: $progress% (${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB / ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB)');
            }
          }
        }

        await outputStream.close();
      } catch (e) {
        await outputStream.close();
        if (await cacheFile.exists()) {
          await cacheFile.delete();
        }
        rethrow;
      }

      // Verifica che il file sia stato copiato correttamente
      if (!await cacheFile.exists()) {
        throw Exception('File non copiato correttamente');
      }

      final copiedSize = await cacheFile.length();
      if (fileSize > 0 && copiedSize != fileSize) {
        throw Exception('Dimensione file non corrisponde: atteso $fileSize, copiato $copiedSize');
      }

      DebugLogger.info('✅ [FilePicker] File copiato in cache: ${cacheFile.path} (${(copiedSize / (1024 * 1024)).toStringAsFixed(2)} MB)');

      return cacheFile;
    } catch (e) {
      DebugLogger.error('❌ [FilePicker] Errore copia file da cloud storage: $e');
      return null;
    }
  }

  Future<void> _updateEstimatedSize() async {
    if (_selectedVideo == null || _videoMetadata == null) {
      return;
    }

    setState(() {
      _isCalculatingSize = true;
    });

    try {
      // Calcolo dimensione prevista
      final estimatedSize = await VideoCompressionService.estimateCompressedSize(
        inputFile: _selectedVideo!,
        settings: _compressionSettings,
        originalMetadata: _videoMetadata,
      );

      // Dimensione prevista calcolata

      if (mounted) {
        setState(() {
          _estimatedCompressedSize = estimatedSize;
          _isCalculatingSize = false;
        });
      }
    } catch (e) {
      // Errore calcolo dimensione (silenzioso)
      if (mounted) {
        setState(() {
          _estimatedCompressedSize = null;
          _isCalculatingSize = false;
        });
      }
    }
  }

  Future<void> _handleUpload() async {
    if (_selectedVideo == null) return;

    // Check connectivity
    try {
      await ConnectivityService.ensureOnline();
    } catch (e) {
      _showError('No internet connection. Please check your connection.');
      return;
    }

    setState(() {
      _isProcessing = false;
      _isCompressing = false;
      _progress = 0.0;
      _compressionProgress = 0.0;
      _statusMessage = null;
      _compressionStatusMessage = null;
    });

    // Usa ViewModel già inizializzato
    try {
      // Usa titolo modificato dall'utente, o fallback a nome file se vuoto
      final videoPath = _selectedVideo!.path;
      final videoName = videoPath.split(Platform.pathSeparator).last;
      final title = _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : videoName;

      // Normalizza la data a 12:00:00 UTC se presente
      DateTime? normalizedDate;
      if (_recordedDate != null) {
        normalizedDate = DateTime.utc(
          _recordedDate!.year,
          _recordedDate!.month,
          _recordedDate!.day,
          12,
          0,
          0,
        );
        DebugLogger.info('📅 [Upload] Data registrazione normalizzata: ${_recordedDate} -> ${normalizedDate}');
      } else {
        DebugLogger.info('📅 [Upload] Nessuna data registrazione impostata');
      }

      // Usa la coda anche per il singolo file
      _viewModel!.queueUpload(
        videoFile: _selectedVideo!,
        title: title,
        compressionSettings: _compressionSettings,
        recordedDate: normalizedDate,
      );

      // Reset UI dopo aver aggiunto alla coda
      _showSuccess('File aggiunto alla coda di upload');
      setState(() {
        _selectedVideo = null;
        _videoMetadata = null;
        _estimatedCompressedSize = null;
        _isProcessing = false;
        _isCompressing = false;
        _progress = 0.0;
        _compressionProgress = 0.0;
        _statusMessage = null;
        _compressionStatusMessage = null;
        _titleController.clear(); // Pulisci campo titolo
        _recordedDate = null; // Pulisci data registrazione
      });
    } on FFmpegNotInstalledException catch (e) {
      // FFmpeg non installato: offre installazione automatica
      setState(() {
        _isProcessing = false;
        _isCompressing = false;
      });

      // Mostra dialog per installazione
      final shouldInstall = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('FFmpeg Richiesto'),
          content: const Text(
            'FFmpeg non è installato. Vuoi installarlo automaticamente tramite winget?\n\n'
            'L\'installazione richiederà privilegi di amministratore.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Installa'),
            ),
          ],
        ),
      );

      if (shouldInstall == true) {
        // Installa FFmpeg tramite winget
        await _installFFmpegWithWinget();
      }
    } catch (e) {
      _showError('Upload failed: $e');
      setState(() {
        _isProcessing = false;
        _isCompressing = false;
        _progress = 0.0;
        _compressionProgress = 0.0;
        _statusMessage = null;
        _compressionStatusMessage = null;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _selectRecordedDate() async {
    if (!mounted) return;

    final DateTime now = DateTime.now();

    // Su Android e Windows, usa un approccio più semplice senza locale per evitare problemi
    final isMobileOrWindows = Platform.isAndroid || Platform.isWindows;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _recordedDate ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
      locale: isMobileOrWindows ? null : const Locale('it', 'IT'), // Su Android/Windows non forzare locale
      helpText: 'Seleziona data registrazione',
      cancelText: 'Annulla',
      confirmText: 'Conferma',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
            scaffoldBackgroundColor: Colors.white,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _recordedDate = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Mostra dialog per installazione FFmpeg
  Future<void> _showFFmpegInstallationDialog() async {
    if (!mounted) return;

    final shouldInstall = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('FFmpeg Richiesto'),
        content: const Text(
          'FFmpeg non è installato sul sistema.\n\n'
          'FFmpeg è necessario per la compressione video. Vuoi installarlo automaticamente tramite winget?\n\n'
          'L\'installazione richiederà privilegi di amministratore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Installa'),
          ),
        ],
      ),
    );

    if (shouldInstall == true) {
      // Installa FFmpeg tramite winget
      await _installFFmpegWithWinget();
    }
  }

  /// Controlla FFmpeg su Windows all'apertura della schermata
  Future<void> _checkFFmpegOnWindows() async {
    if (!mounted || !Platform.isWindows) {
      return;
    }

    // Verifica se FFmpeg è installato
    // Su Windows, potrebbe essere necessario aggiornare il PATH
    final status = await FFmpegInstallationService.checkFFmpegStatus();

    if (!status.isInstalled) {
      // Mostra dialog per installazione automatica
      final shouldInstall = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('FFmpeg Richiesto'),
          content: const Text(
            'FFmpeg non è installato sul sistema.\n\n'
            'FFmpeg è necessario per la compressione video. Vuoi installarlo automaticamente tramite winget?\n\n'
            'L\'installazione richiederà privilegi di amministratore.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Installa'),
            ),
          ],
        ),
      );

      if (shouldInstall == true) {
        // Installa FFmpeg tramite winget
        await _installFFmpegWithWinget();
      }
    }
  }

  /// Installa FFmpeg tramite winget
  Future<void> _installFFmpegWithWinget() async {
    // Mostra dialog di progresso
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Installazione FFmpeg in corso...'),
            SizedBox(height: 8),
            Text(
              'Questo richiederà privilegi di amministratore.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );

    try {
      // Esegui winget install
      final result = await Process.run(
        'winget',
        [
          'install',
          '--id', 'gyan.FFmpeg',
          '--silent',
          '--accept-package-agreements',
          '--accept-source-agreements',
        ],
      );

      // Chiudi dialog di progresso
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (result.exitCode == 0) {
        // Attendi che winget completi l'aggiornamento PATH
        await Future.delayed(const Duration(seconds: 2));

        // Verifica installazione
        final isInstalled = await FFmpegInstallationService.isFFmpegInstalled();
        if (isInstalled) {
          _showSuccess('FFmpeg installato con successo! Puoi ora usare la compressione video.');
        } else {
          _showError('FFmpeg installato ma non ancora disponibile. Riavvia l\'app per applicare le modifiche al PATH.');
        }
      } else {
        final errorOutput = result.stderr.toString();
        _showError('Installazione FFmpeg fallita: $errorOutput\n\nAssicurati di avere privilegi di amministratore.');
      }
    } catch (e) {
      // Chiudi dialog di progresso se ancora aperto
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (e.toString().contains('winget') || e.toString().contains('not found')) {
        _showError('winget non è disponibile. Installa Microsoft Store e aggiorna Windows per ottenere winget.');
      } else {
        _showError('Errore durante l\'installazione: $e');
      }
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _handleCancelCurrent() async {
    final currentTask = _viewModel!.currentUploadTask;
    if (currentTask == null) {
      return;
    }

    // Mostra dialog di conferma
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annulla Upload'),
        content: Text('Sei sicuro di voler annullare l\'upload di "${currentTask.remoteFileName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _viewModel!.cancelUpload(currentTask.id);
        _showSuccess('Upload annullato');
      } catch (e) {
        _showError('Errore durante l\'annullamento: $e');
      }
    }
  }

  Future<void> _handleCancelAll() async {
    // Mostra dialog di conferma
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annulla Task'),
        content: const Text('Sei sicuro di voler annullare tutte le task attive (compressione e upload)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _viewModel!.cancelAllActiveTasks();
        _showSuccess('Task annullate con successo');

        // Reset UI state
        setState(() {
          _isProcessing = false;
          _isCompressing = false;
          _progress = 0.0;
          _compressionProgress = 0.0;
          _statusMessage = null;
          _compressionStatusMessage = null;
        });
      } catch (e) {
        _showError('Errore durante l\'annullamento: $e');
      }
    }
  }

  Future<void> _handleClearCompleted() async {
    // Mostra dialog di conferma
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pulisci Task Completate'),
        content: const Text('Sei sicuro di voler rimuovere tutte le task completate, cancellate o con errori?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _viewModel!.clearCompletedTasks();
        _showSuccess('Task completate rimosse con successo');
      } catch (e) {
        _showError('Errore durante la pulizia: $e');
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Widget _buildActiveUploads() {
    // Mostra solo il task corrente (sequenziale)
    final currentTask = _viewModel!.currentUploadTask;

    // Se c'è un task attivo, mostralo
    if (currentTask != null &&
        (currentTask.status == UploadStatus.uploading ||
         currentTask.status == UploadStatus.compressing)) {
      return _buildSingleTaskCard(currentTask);
    }

    // Se c'è una coda ma nessun task attivo, mostra info coda
    if (_viewModel!.queueLength > 0 && !_viewModel!.isProcessingQueue) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'In attesa di avviare upload... (${_viewModel!.queueLength} in coda)',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSingleTaskCard(UploadTask task) {
    // Usa progress dal ViewModel (più aggiornato) o dal task come fallback
    final currentProgress = _viewModel!.currentUploadTask?.id == task.id
        ? _viewModel!.uploadProgress
        : task.progress;
    final currentStatusMessage = _viewModel!.currentUploadTask?.id == task.id
        ? (_viewModel!.isCompressing ? _viewModel!.compressionStatusMessage : _viewModel!.uploadStatusMessage)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mostra info coda se ci sono altri file in attesa
        if (_viewModel!.queueLength > 0) ...[
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  const Icon(Icons.queue, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    '${_viewModel!.queueLength} file in coda',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Card task corrente
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nome file e stato
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.remoteFileName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Badge stato
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(task.status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusLabel(task.status),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Progress bar con stato dettagliato
                if (task.status == UploadStatus.compressing) ...[
                  // Mostra progress compressione
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Compressione',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            '${(currentProgress * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: currentProgress.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentStatusMessage ??
                        '${_formatFileSize(task.uploadedBytes)} / ${_formatFileSize(task.totalBytes)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ] else if (task.status == UploadStatus.uploading) ...[
                  // Mostra progress upload
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Upload',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            '${(currentProgress * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: currentProgress.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentStatusMessage ??
                        '${_formatFileSize(task.uploadedBytes)} / ${_formatFileSize(task.totalBytes)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ] else if (task.status == UploadStatus.queued) ...[
                  // Mostra stato in coda
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'In attesa...',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 8),

                // Pulsante annulla
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _viewModel!.cancelUpload(task.id),
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Annulla'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildActiveUploadsOld() {
    final activeTasks = _viewModel!.uploadTasks.where(
      (task) => task.status == UploadStatus.uploading ||
                task.status == UploadStatus.compressing ||
                task.status == UploadStatus.queued
    ).toList();

    if (activeTasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload in corso',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...activeTasks.map((task) => Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome file e stato
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.remoteFileName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Badge stato
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(task.status),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStatusLabel(task.status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Progress bar con stato dettagliato
                  if (task.status == UploadStatus.compressing) ...[
                    // Mostra progress compressione
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Compressione',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              '${(task.progress * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: task.progress,
                          minHeight: 6,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatFileSize(task.uploadedBytes)} / ${_formatFileSize(task.totalBytes)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ] else if (task.status == UploadStatus.uploading) ...[
                    // Mostra progress upload
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Upload',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              '${(task.progress * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: task.progress,
                          minHeight: 6,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatFileSize(task.uploadedBytes)} / ${_formatFileSize(task.totalBytes)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ] else if (task.status == UploadStatus.queued) ...[
                    // Mostra stato in coda
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'In attesa...',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Pulsante annulla
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _viewModel!.cancelUpload(task.id),
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Annulla'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        )),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Restituisce colore per stato task
  Color _getStatusColor(UploadStatus status) {
    switch (status) {
      case UploadStatus.queued:
        return Colors.grey;
      case UploadStatus.compressing:
        return Colors.orange;
      case UploadStatus.uploading:
        return Colors.blue;
      case UploadStatus.completed:
        return Colors.green;
      case UploadStatus.error:
        return Colors.red;
      case UploadStatus.cancelled:
        return Colors.grey;
      case UploadStatus.scanning:
        return Colors.purple;
    }
  }

  /// Restituisce label per stato task
  String _getStatusLabel(UploadStatus status) {
    switch (status) {
      case UploadStatus.queued:
        return 'In coda';
      case UploadStatus.compressing:
        return 'Compressione';
      case UploadStatus.uploading:
        return 'Upload';
      case UploadStatus.completed:
        return 'Completato';
      case UploadStatus.error:
        return 'Errore';
      case UploadStatus.cancelled:
        return 'Annullato';
      case UploadStatus.scanning:
        return 'Scansione';
    }
  }

  Widget _buildCompletedUploads() {
    final completedTasks = _viewModel!.uploadTasks.where(
      (task) => task.status == UploadStatus.completed
    ).take(5).toList();

    if (completedTasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload completati',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...completedTasks.map((task) => Card(
          child: ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: Text(task.remoteFileName),
            subtitle: Text(
              task.completedAt != null
                ? 'Completato: ${task.completedAt!.toLocal().toString().split('.')[0]}'
                : 'N/A',
            ),
            trailing: Text(
              _formatFileSize(task.totalBytes),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        )),
      ],
    );
  }
}
