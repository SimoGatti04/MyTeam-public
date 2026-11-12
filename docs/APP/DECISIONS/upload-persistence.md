# Upload Persistence - Client Implementation

## Strategia

- **Persistenza client-side** con SharedPreferences
- **Recupero stato all'avvio** della schermata upload
- **Mostra upload in corso/completati** anche dopo cambio schermata

---

## Implementazione

### 1. Persistenza Upload Task

**File:** `lib/data/datasources/local/upload_local_datasource.dart`

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../domain/entities/upload_task.dart';

class UploadLocalDataSource {
  static const String _keyPrefix = 'upload_task_';
  static const String _activeTasksKey = 'active_upload_tasks';
  
  Future<void> saveUploadTask(UploadTask task) async {
    final prefs = await SharedPreferences.getInstance();
    final taskJson = jsonEncode(_taskToJson(task));
    await prefs.setString('$_keyPrefix${task.id}', taskJson);
    
    // Aggiungi ID alla lista task attivi
    final activeTasks = prefs.getStringList(_activeTasksKey) ?? [];
    if (!activeTasks.contains(task.id)) {
      activeTasks.add(task.id);
      await prefs.setStringList(_activeTasksKey, activeTasks);
    }
  }
  
  Future<void> updateUploadTask(UploadTask task) async {
    await saveUploadTask(task);
  }
  
  Future<UploadTask?> getUploadTask(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final taskJson = prefs.getString('$_keyPrefix$taskId');
    if (taskJson == null) return null;
    return _taskFromJson(jsonDecode(taskJson));
  }
  
  Future<List<UploadTask>> getActiveUploadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final activeTaskIds = prefs.getStringList(_activeTasksKey) ?? [];
    
    final tasks = <UploadTask>[];
    for (final taskId in activeTaskIds) {
      final task = await getUploadTask(taskId);
      if (task != null && 
          (task.status == UploadStatus.uploading || 
           task.status == UploadStatus.compressing)) {
        tasks.add(task);
      }
    }
    return tasks;
  }
  
  Future<List<UploadTask>> getCompletedUploadTasks({int limit = 10}) async {
    final prefs = await SharedPreferences.getInstance();
    final activeTaskIds = prefs.getStringList(_activeTasksKey) ?? [];
    
    final tasks = <UploadTask>[];
    for (final taskId in activeTaskIds) {
      final task = await getUploadTask(taskId);
      if (task != null && task.status == UploadStatus.completed) {
        tasks.add(task);
      }
    }
    
    // Ordina per data completamento (più recenti prima)
    tasks.sort((a, b) => 
      (b.completedAt ?? DateTime.now())
        .compareTo(a.completedAt ?? DateTime.now()));
    
    return tasks.take(limit).toList();
  }
  
  Future<void> removeUploadTask(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$taskId');
    
    final activeTasks = prefs.getStringList(_activeTasksKey) ?? [];
    activeTasks.remove(taskId);
    await prefs.setStringList(_activeTasksKey, activeTasks);
  }
  
  Map<String, dynamic> _taskToJson(UploadTask task) {
    return {
      'id': task.id,
      'videoId': task.videoId,
      'localFilePath': task.localFilePath,
      'remoteFileName': task.remoteFileName,
      'totalBytes': task.totalBytes,
      'uploadedBytes': task.uploadedBytes,
      'status': task.status.name,
      'progress': task.progress,
      'errorMessage': task.errorMessage,
      'createdAt': task.createdAt.toIso8601String(),
      'startedAt': task.startedAt?.toIso8601String(),
      'completedAt': task.completedAt?.toIso8601String(),
    };
  }
  
  UploadTask _taskFromJson(Map<String, dynamic> json) {
    return UploadTask(
      id: json['id'],
      videoId: json['videoId'],
      localFilePath: json['localFilePath'],
      remoteFileName: json['remoteFileName'],
      totalBytes: json['totalBytes'],
      uploadedBytes: json['uploadedBytes'],
      status: UploadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => UploadStatus.queued,
      ),
      progress: (json['progress'] as num).toDouble(),
      errorMessage: json['errorMessage'],
      createdAt: DateTime.parse(json['createdAt']),
      startedAt: json['startedAt'] != null 
        ? DateTime.parse(json['startedAt']) 
        : null,
      completedAt: json['completedAt'] != null 
        ? DateTime.parse(json['completedAt']) 
        : null,
    );
  }
}
```

### 2. Aggiornamento Repository

**File:** `lib/data/repositories/upload_repository_impl.dart`

```dart
class UploadRepositoryImpl implements UploadRepository {
  final UploadRemoteDataSource remoteDataSource;
  final UploadLocalDataSource localDataSource; // Aggiunto
  
  // In-memory storage per task correnti
  final Map<String, UploadTask> _uploadTasks = {};
  
  @override
  Future<Video> uploadVideo({
    required String localFilePath,
    required String title,
    required Function(int sent, int total) onProgress,
    // ... altri parametri
  }) async {
    // Crea upload task
    final uploadTask = UploadTask(/* ... */);
    _uploadTasks[taskId] = uploadTask;
    
    // Salva in persistenza
    await localDataSource.saveUploadTask(uploadTask);
    
    try {
      // Upload con progress
      final videoResponse = await remoteDataSource.uploadVideo(
        // ...
        onProgress: (sent, total) {
          // Update task
          final updatedTask = uploadTask.copyWith(
            uploadedBytes: sent,
            progress: total > 0 ? sent / total : 0.0,
          );
          _uploadTasks[taskId] = updatedTask;
          
          // Salva in persistenza
          localDataSource.updateUploadTask(updatedTask);
          
          // Callback progress
          onProgress(sent, total);
        },
      );
      
      // Task completato
      final completedTask = uploadTask.copyWith(
        videoId: videoResponse.id,
        status: UploadStatus.completed,
        progress: 1.0,
        completedAt: DateTime.now(),
      );
      _uploadTasks[taskId] = completedTask;
      await localDataSource.updateUploadTask(completedTask);
      
      return videoResponse.toEntity();
    } catch (e) {
      // Task errore
      final errorTask = uploadTask.copyWith(
        status: UploadStatus.error,
        errorMessage: e.toString(),
      );
      _uploadTasks[taskId] = errorTask;
      await localDataSource.updateUploadTask(errorTask);
      rethrow;
    }
  }
  
  @override
  Future<List<UploadTask>> getActiveUploads() async {
    // Carica da persistenza
    return await localDataSource.getActiveUploadTasks();
  }
  
  @override
  Future<List<UploadTask>> getCompletedUploads({int limit = 10}) async {
    return await localDataSource.getCompletedUploadTasks(limit: limit);
  }
}
```

### 3. Aggiornamento ViewModel

**File:** `lib/features/upload/viewmodels/upload_viewmodel.dart`

```dart
class UploadViewModel extends ChangeNotifier {
  final UploadVideoUseCase uploadUseCase;
  
  List<UploadTask> _uploadTasks = [];
  bool _isUploading = false;
  String? _error;
  
  List<UploadTask> get uploadTasks => _uploadTasks;
  bool get isUploading => _isUploading;
  String? get error => _error;
  
  /// Carica upload task salvati all'avvio
  Future<void> loadSavedUploadTasks() async {
    _isUploading = true;
    notifyListeners();
    
    try {
      // Carica upload attivi
      final activeTasks = await uploadUseCase.getActiveUploads();
      _uploadTasks = activeTasks;
      
      // Carica upload completati (ultimi 10)
      final completedTasks = await uploadUseCase.getCompletedUploads(limit: 10);
      _uploadTasks.addAll(completedTasks);
      
      _isUploading = _uploadTasks.any(
        (task) => task.status == UploadStatus.uploading || 
                  task.status == UploadStatus.compressing
      );
    } catch (e) {
      _error = 'Failed to load upload tasks: $e';
    } finally {
      notifyListeners();
    }
  }
  
  /// Upload video
  Future<Video?> uploadVideo({
    required File videoFile,
    required String title,
    required CompressionSettings compressionSettings,
  }) async {
    // ... implementazione esistente ...
    // Il repository salva automaticamente in persistenza
  }
}
```

### 4. Aggiornamento UI

**File:** `lib/presentation/screens/upload/upload_screen.dart`

```dart
class _UploadScreenState extends State<UploadScreen> {
  late UploadViewModel _viewModel;
  
  @override
  void initState() {
    super.initState();
    // Inizializza ViewModel
    final apiClient = ApiClient();
    final remoteDataSource = UploadRemoteDataSource(apiClient);
    final localDataSource = UploadLocalDataSource(); // Aggiunto
    final repository = UploadRepositoryImpl(remoteDataSource, localDataSource);
    final uploadUseCase = UploadVideoUseCase(repository);
    _viewModel = UploadViewModel(uploadUseCase);
    _viewModel.addListener(_onViewModelChanged);
    
    // Carica upload salvati
    _viewModel.loadSavedUploadTasks();
  }
  
  void _onViewModelChanged() {
    setState(() {});
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Video')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // File selection
            _buildFileSelection(),
            
            // Upload in corso
            if (_viewModel.uploadTasks.any(
              (task) => task.status == UploadStatus.uploading || 
                        task.status == UploadStatus.compressing
            ))
              _buildActiveUploads(),
            
            // Upload completati
            if (_viewModel.uploadTasks.any(
              (task) => task.status == UploadStatus.completed
            ))
              _buildCompletedUploads(),
            
            // ... resto UI ...
          ],
        ),
      ),
    );
  }
  
  Widget _buildActiveUploads() {
    final activeTasks = _viewModel.uploadTasks.where(
      (task) => task.status == UploadStatus.uploading || 
                task.status == UploadStatus.compressing
    ).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Upload in corso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ...activeTasks.map((task) => UploadProgressWidget(
          progress: task.progress,
          statusMessage: '${task.remoteFileName} - ${(task.progress * 100).toStringAsFixed(1)}%',
        )),
      ],
    );
  }
  
  Widget _buildCompletedUploads() {
    final completedTasks = _viewModel.uploadTasks.where(
      (task) => task.status == UploadStatus.completed
    ).take(10).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Upload completati', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ...completedTasks.map((task) => ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: Text(task.remoteFileName),
          subtitle: Text('Completato: ${task.completedAt?.toString().split(' ')[0]}'),
        )),
      ],
    );
  }
}
```

---

## Dipendenze

Aggiungere a `pubspec.yaml`:

```yaml
dependencies:
  shared_preferences: ^2.2.2
```

---

## Note

- **Persistenza solo client-side**: Se l'app viene disinstallata, i dati vengono persi
- **Performance**: Carica solo upload attivi e ultimi 10 completati
- **Futuro**: Possibilità di sincronizzazione con server per persistenza cross-device

