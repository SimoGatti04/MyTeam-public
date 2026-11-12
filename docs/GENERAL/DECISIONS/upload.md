# Upload Video - Implementazione

## Flusso

```
1. Client: Seleziona video originale
   ↓
2. Client: Estrae metadata originale
   ↓
3. Client: Utente sceglie risoluzione e framerate
   ↓
4. Client: Comprime video (FFmpeg)
   ↓
5. Client: Upload video compresso al server
   ↓
6. Server: Valida file
   ↓
7. Server: Crea entry upload queue
   ↓
8. Server: Salva file su disco
   ↓
9. Server: Crea entry video database
   ↓
10. Server: Background task - Estrae metadata
   ↓
11. Server: Background task - Genera thumbnail
   ↓
12. Server: Aggiorna video status a "ready"
```

---

## Client-Side Implementation

### 1. Selezione Video

**Package:** `file_picker`

```dart
// lib/features/upload/services/file_picker_service.dart
import 'package:file_picker/file_picker.dart';

class FilePickerService {
  Future<File?> pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    
    if (result != null && result.files.single.path != null) {
      return File(result.files.single.path!);
    }
    return null;
  }
}
```

### 2. Estrazione Metadata Originale

**Package:** `ffmpeg_kit_flutter_new`

```dart
// lib/core/services/video_metadata_service.dart
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'dart:convert';

class VideoMetadataService {
  static Future<Map<String, dynamic>> extractMetadata(String videoPath) async {
    final session = await FFprobeKit.execute(
      '-v quiet -print_format json -show_format -show_streams "$videoPath"',
    );
    
    final returnCode = await session.getReturnCode();
    if (returnCode?.isValueSuccess() ?? false) {
      final output = await session.getOutput();
      if (output != null) {
        final jsonData = json.decode(output) as Map<String, dynamic>;
        return _parseMetadata(jsonData);
      }
    }
    
    final failStackTrace = await session.getFailStackTrace();
    throw Exception('FFprobe failed: ${failStackTrace ?? "Unknown error"}');
  }
  
  static Map<String, dynamic> _parseMetadata(Map<String, dynamic> json) {
    final format = json['format'] as Map<String, dynamic>?;
    final streams = json['streams'] as List<dynamic>?;
    
    final videoStream = streams?.firstWhere(
      (s) => s['codec_type'] == 'video',
      orElse: () => null,
    ) as Map<String, dynamic>?;
    
    if (videoStream == null) {
      throw Exception('No video stream found');
    }
    
    return {
      'width': videoStream['width'] as int?,
      'height': videoStream['height'] as int?,
      'framerate': _parseFramerate(videoStream['r_frame_rate'] as String?),
      'duration': format?['duration'] != null 
        ? double.tryParse(format!['duration'] as String) 
        : null,
      'fileSize': format?['size'] != null 
        ? int.tryParse(format!['size'] as String) 
        : null,
      'codec': videoStream['codec_name'] as String?,
      'bitrate': format?['bit_rate'] != null 
        ? int.tryParse(format!['bit_rate'] as String) 
        : null,
    };
  }
  
  static double? _parseFramerate(String? rFrameRate) {
    if (rFrameRate == null) return null;
    final parts = rFrameRate.split('/');
    if (parts.length == 2) {
      final num = double.tryParse(parts[0]);
      final den = double.tryParse(parts[1]);
      if (num != null && den != null && den != 0) {
        return num / den;
      }
    }
    return null;
  }
}
```

### 3. Upload Video

**Package:** `dio`

```dart
// lib/data/datasources/remote/upload_remote_datasource.dart
import 'dart:io';
import 'package:dio/dio.dart';

class UploadRemoteDataSource {
  final Dio dio;
  
  Future<VideoResponse> uploadVideo({
    required File videoFile,
    required String title,
    int? originalResolutionWidth,
    int? originalResolutionHeight,
    double? originalFramerate,
    double? compressedFramerate,
    int? originalFileSize,
    required Function(int sent, int total) onProgress,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        videoFile.path,
        filename: videoFile.path.split('/').last,
      ),
      'title': title,
      if (originalResolutionWidth != null)
        'original_resolution_width': originalResolutionWidth,
      if (originalResolutionHeight != null)
        'original_resolution_height': originalResolutionHeight,
      if (originalFramerate != null)
        'original_framerate': originalFramerate,
      if (compressedFramerate != null)
        'compressed_framerate': compressedFramerate,
      if (originalFileSize != null)
        'original_file_size': originalFileSize,
    });
    
    final response = await dio.post(
      '/api/videos',
      data: formData,
      onSendProgress: onProgress,
    );
    
    return VideoResponse.fromJson(response.data);
  }
}
```

---

## Server-Side Implementation

### Upload Endpoint

**File:** `app/api/routes/videos.py`

```python
from fastapi import APIRouter, UploadFile, Form, BackgroundTasks, Depends, Request
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.services.video_service import VideoService
from app.services.upload_queue_service import UploadQueueService
from app.schemas.video import VideoResponse
from app.utils.file_validation import validate_file
from app.core.config import get_settings
from app.core.storage import save_file_to_disk, check_disk_space
from app.services.background_tasks import extract_metadata_task, generate_thumbnail_task

router = APIRouter()
settings = get_settings()

@router.post("/api/videos", response_model=VideoResponse)
async def upload_video(
    request: Request,
    file: UploadFile,
    title: str = Form(None),
    original_resolution_width: int = Form(None),
    original_resolution_height: int = Form(None),
    original_framerate: float = Form(None),
    compressed_framerate: float = Form(None),
    original_file_size: int = Form(None),
    background_tasks: BackgroundTasks = BackgroundTasks(),
    db: Session = Depends(get_db),
):
    # Validazione file
    validate_file(file, request_headers=dict(request.headers))
    
    # Disk space check (per file >10GB)
    file_size = None
    if 'content-length' in request.headers:
        file_size = int(request.headers['content-length'])
    elif original_file_size:
        file_size = original_file_size
    
    if file_size and file_size > 10 * 1024 * 1024 * 1024:
        check_disk_space(file_size, settings.VIDEOS_PATH)
    
    # Crea upload queue entry
    upload_queue_service = UploadQueueService(db)
    upload_queue = upload_queue_service.create_upload_queue_entry(
        filename=file.filename or "unknown",
        file_path="",
        file_size=file_size or original_file_size or 0,
    )
    
    # Salva video metadata
    video_service = VideoService(db)
    video = video_service.save_video(
        file=file,
        title=title or file.filename or "Untitled",
        original_resolution_width=original_resolution_width,
        original_resolution_height=original_resolution_height,
        original_framerate=original_framerate,
        compressed_framerate=compressed_framerate,
        original_file_size=original_file_size,
    )
    
    # Aggiorna upload queue
    upload_queue_service.update_upload_queue_status(
        upload_id=upload_queue.id,
        status="processing",
        video_id=video.id,
        progress=0.0,
    )
    
    # Salva file su disco
    await save_file_to_disk(file, video.file_path)
    
    # Aggiorna file size e progress
    file_size = os.path.getsize(video.file_path)
    video = video_service.update_video_file_size(video.id, file_size)
    upload_queue_service.update_upload_progress(
        upload_id=upload_queue.id,
        uploaded_bytes=file_size,
    )
    upload_queue_service.update_upload_queue_status(
        upload_id=upload_queue.id,
        status="completed",
        progress=1.0,
    )
    
    # Background tasks
    background_tasks.add_task(extract_metadata_task, video.id)
    background_tasks.add_task(generate_thumbnail_task, video.id)
    
    return video
```

---

## Packages Necessari

### Flutter

```yaml
dependencies:
  file_picker: ^10.3.3
  ffmpeg_kit_flutter_new: ^2.0.0
  dio: ^5.4.0
  path_provider: ^2.1.1
```

### Server

```txt
fastapi==0.104.1
python-multipart==0.0.6
aiofiles==23.1.0
sqlalchemy==2.0.23
pydantic==2.5.0
pydantic-settings==2.1.0
uvicorn[standard]==0.24.0
```
