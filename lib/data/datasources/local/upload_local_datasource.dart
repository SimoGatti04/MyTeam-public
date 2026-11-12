import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/entities/upload_task.dart';

/// Upload local data source - Data layer
/// Persistenza upload task con SharedPreferences
class UploadLocalDataSource {
  static const String _keyPrefix = 'upload_task_';
  static const String _activeTasksKey = 'active_upload_tasks';
  
  /// Salva upload task in persistenza
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
  
  /// Aggiorna upload task in persistenza
  Future<void> updateUploadTask(UploadTask task) async {
    await saveUploadTask(task);
  }
  
  /// Recupera upload task da persistenza
  Future<UploadTask?> getUploadTask(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final taskJson = prefs.getString('$_keyPrefix$taskId');
    if (taskJson == null) return null;
    return _taskFromJson(jsonDecode(taskJson));
  }
  
  /// Recupera upload task attivi (uploading, compressing)
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
  
  /// Recupera upload task completati (ultimi N, max 24h)
  Future<List<UploadTask>> getCompletedUploadTasks({int limit = 5}) async {
    final prefs = await SharedPreferences.getInstance();
    final activeTaskIds = prefs.getStringList(_activeTasksKey) ?? [];
    final now = DateTime.now();
    final maxAge = const Duration(hours: 24);
    
    final tasks = <UploadTask>[];
    final tasksToRemove = <String>[];
    
    for (final taskId in activeTaskIds) {
      final task = await getUploadTask(taskId);
      if (task != null && task.status == UploadStatus.completed) {
        // Rimuovi task completati > 24h
        if (task.completedAt != null) {
          final age = now.difference(task.completedAt!);
          if (age > maxAge) {
            tasksToRemove.add(taskId);
            continue;
          }
        }
        tasks.add(task);
      }
    }
    
    // Rimuovi task vecchi
    for (final taskId in tasksToRemove) {
      await removeUploadTask(taskId);
    }
    
    // Ordina per data completamento (più recenti prima)
    tasks.sort((a, b) => 
      (b.completedAt ?? DateTime.now())
        .compareTo(a.completedAt ?? DateTime.now()));
    
    return tasks.take(limit).toList();
  }
  
  /// Recupera tutti gli upload task
  Future<List<UploadTask>> getAllUploadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final activeTaskIds = prefs.getStringList(_activeTasksKey) ?? [];
    
    final tasks = <UploadTask>[];
    for (final taskId in activeTaskIds) {
      final task = await getUploadTask(taskId);
      if (task != null) {
        tasks.add(task);
      }
    }
    return tasks;
  }
  
  /// Rimuove upload task da persistenza
  Future<void> removeUploadTask(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$taskId');
    
    final activeTasks = prefs.getStringList(_activeTasksKey) ?? [];
    activeTasks.remove(taskId);
    await prefs.setStringList(_activeTasksKey, activeTasks);
  }
  
  /// Converte UploadTask a JSON
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
  
  /// Converte JSON a UploadTask
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

