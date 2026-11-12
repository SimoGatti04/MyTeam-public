# Client-Side Upload Flow

## Strategia

- **Connectivity check** prima upload
- **Timeout configurabile** per upload
- **Retry automatico** max 5 tentativi su errori temporanei
- **Upload multipli** non bloccanti (errori isolati)
- **Notifiche a fine processo** (summary successi/fallimenti)

---

## Connectivity Check

```dart
// lib/core/services/connectivity_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();
  
  static Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    if (result is List<ConnectivityResult>) {
      return !result.contains(ConnectivityResult.none);
    }
    return result != ConnectivityResult.none;
  }
  
  static Stream<List<ConnectivityResult>> connectivityStream() {
    return _connectivity.onConnectivityChanged;
  }
  
  static Future<void> ensureOnline() async {
    if (!await isOnline()) {
      throw ConnectivityException('No internet connection');
    }
  }
}
```

**Uso:**
```dart
// Prima di iniziare upload
await ConnectivityService.ensureOnline();
```

---

## Timeout Configurabile

```dart
// lib/core/constants/app_constants.dart
class AppConstants {
  static const Duration uploadTimeout = Duration(hours: 24);
}

// lib/features/upload/services/upload_service.dart
class UploadService {
  Future<void> uploadVideo({
    required File compressedFile,
    required Function(int sent, int total) onProgress,
    Duration? timeout,
  }) async {
    final uploadTimeout = timeout ?? AppConstants.uploadTimeout;
    
    await dio.post(
      '/api/videos',
      data: formData,
      onSendProgress: onProgress,
      options: Options(
        sendTimeout: uploadTimeout,
        receiveTimeout: uploadTimeout,
      ),
    );
  }
}
```

---

## Upload Multipli Non Bloccanti

```dart
// lib/features/upload/services/multi_upload_service.dart
class MultiUploadService {
  Future<Map<String, UploadResult>> uploadMultipleVideos({
    required List<UploadTask> tasks,
    required Function(int completed, int total) onProgress,
    required Function(Map<String, UploadResult> results) onComplete,
  }) async {
    await ConnectivityService.ensureOnline();
    
    final results = <String, UploadResult>{};
    int completed = 0;
    
    await Future.wait(
      tasks.map((task) async {
        try {
          await uploadVideoWithRetry(
            compressedFile: task.compressedFile,
            originalMetadata: task.originalMetadata,
            targetResolution: task.targetResolution,
            targetFramerate: task.targetFramerate,
          );
          results[task.id] = UploadResult.success();
        } catch (e) {
          results[task.id] = UploadResult.failed(
            error: e.toString(),
            errorLog: getErrorLog(task.id),
          );
        }
        completed++;
        onProgress(completed, tasks.length);
      }),
    );
    
    onComplete(results);
    return results;
  }
}
```

---

## Notifiche a Fine Processo

```dart
// lib/features/upload/widgets/upload_summary_dialog.dart
class UploadSummaryDialog extends StatelessWidget {
  final Map<String, UploadResult> results;
  
  @override
  Widget build(BuildContext context) {
    final successes = results.values.where((r) => r.isSuccess).length;
    
    return AlertDialog(
      title: Text('Upload Completati: $successes/${results.length}'),
      content: Column(
        children: results.entries.map((entry) {
          final result = entry.value;
          return ListTile(
            leading: result.isSuccess 
              ? Icon(Icons.check_circle, color: Colors.green)
              : Icon(Icons.error, color: Colors.red),
            title: Text(entry.key),
            subtitle: result.isSuccess 
              ? Text('Successo')
              : Text('Errore: ${result.error}'),
            trailing: !result.isSuccess 
              ? TextButton(
                  onPressed: () => sendErrorLog(entry.key),
                  child: Text('Invia log'),
                )
              : null,
          );
        }).toList(),
      ),
    );
  }
}
```
