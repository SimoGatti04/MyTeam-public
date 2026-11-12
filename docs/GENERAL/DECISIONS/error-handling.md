# Error Handling e Retry Logic

## Strategia

- **Retry automatico** su errori temporanei con max 5 tentativi
- **Notifica solo all'ultimo errore** (tentativo 5)
- **Log dettagliato** di tutti gli errori per debug

---

## Client-Side Retry Logic

### Implementazione

```dart
// lib/features/upload/services/upload_service.dart
class UploadService {
  static const int MAX_RETRIES = 5;
  
  Future<void> uploadVideoWithRetry({
    required File compressedFile,
    required VideoMetadata originalMetadata,
    required Resolution targetResolution,
    required Framerate targetFramerate,
    required Function(int attempt, String? error) onRetry,
    required Function(String finalError) onFinalError,
  }) async {
    final errorLog = <UploadError>[];
    
    for (int attempt = 1; attempt <= MAX_RETRIES; attempt++) {
      try {
        await uploadVideo(
          compressedFile: compressedFile,
          originalMetadata: originalMetadata,
          targetResolution: targetResolution,
          targetFramerate: targetFramerate,
        );
        return;
      } catch (e) {
        final error = UploadError(
          attempt: attempt,
          timestamp: DateTime.now(),
          error: e.toString(),
          statusCode: (e as DioException?)?.response?.statusCode,
        );
        errorLog.add(error);
        
        if (isTemporaryError(e) && attempt < MAX_RETRIES) {
          onRetry(attempt, e.toString());
          await Future.delayed(Duration(seconds: 1 << attempt)); // Exponential backoff
          continue;
        }
        
        if (attempt == MAX_RETRIES) {
          onFinalError(_formatErrorLog(errorLog));
        }
        rethrow;
      }
    }
  }
  
  bool isTemporaryError(dynamic error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      return statusCode == null || 
             statusCode >= 500 || 
             statusCode == 408 || 
             statusCode == 429;
    }
    return false;
  }
  
  String _formatErrorLog(List<UploadError> errors) {
    return errors.map((e) => 
      'Tentativo ${e.attempt}: ${e.error} (${e.statusCode ?? "N/A"})'
    ).join('\n');
  }
}
```

---

## Server-Side Retry Logic

### Background Tasks

```python
# app/services/background_tasks.py
from app.core.config import get_settings

settings = get_settings()
MAX_RETRIES = settings.MAX_RETRIES_BACKGROUND_TASKS

async def extract_metadata_task(video_id: str) -> None:
    db = SessionLocal()
    try:
        video_service = VideoService(db)
        video = db.query(Video).filter(Video.id == video_id).first()
        if not video:
            return

        retry_count = 0
        last_error = None

        while retry_count < MAX_RETRIES:
            try:
                metadata = await extract_metadata(video.file_path)
                video_service.update_video_metadata(
                    video_id=video_id,
                    duration=metadata.get('duration'),
                    width=metadata.get('width'),
                    height=metadata.get('height'),
                    video_metadata=metadata,
                )
                return
            except Exception as e:
                retry_count += 1
                last_error = e
                if retry_count < MAX_RETRIES:
                    wait_time = 2 ** retry_count
                    await asyncio.sleep(wait_time)

        # Tutti i retry falliti
        error_data = {
            'error': str(last_error),
            'retries': retry_count,
            'video_id': video_id,
            'operation': 'metadata_extraction',
        }
        video_service.update_video_metadata_error(video_id, error_data)
        
        # Log errori
        error_log = ErrorLog(
            video_id=video_id,
            operation='metadata_extraction',
            error_data=error_data
        )
        db.add(error_log)
        db.commit()
    finally:
        db.close()
```

---

## Error Logging

### Client-Side Log Storage

**Location:** Cache directory app (`getTemporaryDirectory()`)

**File Format:** JSON

```dart
// lib/features/upload/services/error_log_service.dart
class ErrorLogService {
  static Future<void> saveUploadError({
    required String videoId,
    required String filename,
    required List<UploadError> errors,
  }) async {
    final directory = await getTemporaryDirectory();
    final logFile = File('${directory.path}/upload_errors_$videoId.json');
    
    final logData = {
      'video_id': videoId,
      'filename': filename,
      'operation': 'upload',
      'timestamp': DateTime.now().toIso8601String(),
      'retries': errors.map((e) => e.toJson()).toList(),
      'final_status': 'failed',
    };
    
    await logFile.writeAsString(jsonEncode(logData));
  }
  
  static Future<void> sendErrorLogToServer({
    required String videoId,
    required Map<String, dynamic> logData,
  }) async {
    await dio.post(
      '$serverUrl/api/debug/upload-errors',
      data: logData,
    );
  }
}
```

### Server-Side Log Storage

**Endpoint:** `POST /api/debug/upload-errors`

```python
# app/api/routes/debug.py
@router.post("/api/debug/upload-errors")
async def save_error_log(log_data: dict, db: Session = Depends(get_db)):
    error_log = ErrorLog(
        video_id=log_data.get("video_id"),
        operation=log_data.get("operation", "upload"),
        error_data=log_data,
    )
    db.add(error_log)
    db.commit()
    return {"status": "ok"}
```

---

## Errori Temporanei vs Permanenti

### Client-Side

**Errori temporanei:**
- Network errors (no connection)
- Timeout (408)
- Server errors (5xx)
- Too many requests (429)

**Errori permanenti:**
- Bad request (400)
- Unauthorized (401)
- Forbidden (403)
- Not found (404)
- File too large (413)

### Server-Side

**Errori temporanei:**
- FFprobe/FFmpeg timeout
- Disk I/O errors
- Database connection errors

**Errori permanenti:**
- Invalid file format
- Corrupted file
- Missing dependencies
