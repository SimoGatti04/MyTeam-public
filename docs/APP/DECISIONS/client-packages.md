# Client-Side Packages

## Packages Necessari

### File Selection

**Package:** `file_picker`

```yaml
dependencies:
  file_picker: ^10.3.3
```

```dart
import 'package:file_picker/file_picker.dart';

final result = await FilePicker.platform.pickFiles(
  type: FileType.video,
  allowMultiple: false,
);
```

---

### Video Metadata & Compression

**Package:** `ffmpeg_kit_flutter_new`

**Nota:** `ffmpeg_kit_flutter` è stato discontinuato (gennaio 2025). Usiamo `ffmpeg_kit_flutter_new`, un fork mantenuto che supporta Android. Per macOS e Windows, usa FFmpeg installato localmente.

```yaml
dependencies:
  ffmpeg_kit_flutter_new: ^2.0.0
```

**Uso per Metadata:**
```dart
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';

final session = await FFprobeKit.execute(
  '-v quiet -print_format json -show_format -show_streams video.mp4'
);
```

**Uso per Compressione:**
```dart
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';

final session = await FFmpegKit.execute(command);
```

---

### HTTP Client

**Package:** `dio`

```yaml
dependencies:
  dio: ^5.4.0
```

```dart
import 'package:dio/dio.dart';

final dio = Dio();
await dio.post(
  '/api/videos',
  data: formData,
  onSendProgress: (sent, total) {
    // Progress tracking
  },
);
```

---

### Cache Directory

**Package:** `path_provider`

```yaml
dependencies:
  path_provider: ^2.1.1
```

```dart
import 'package:path_provider/path_provider.dart';

final directory = await getTemporaryDirectory();
```

---

### Connectivity Check

**Package:** `connectivity_plus`

```yaml
dependencies:
  connectivity_plus: ^7.0.0
```

```dart
import 'package:connectivity_plus/connectivity_plus.dart';

final connectivity = Connectivity();
final result = await connectivity.checkConnectivity();
```

---

## Packages Completi

### `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # File Selection
  file_picker: ^10.3.3
  
  # Video Metadata & Compression
  ffmpeg_kit_flutter_new: ^2.0.0
  
  # HTTP Client
  dio: ^5.4.0
  
  # Cache Directory
  path_provider: ^2.1.1
  
  # Connectivity Check
  connectivity_plus: ^7.0.0
  
  # Video Player
  video_player: ^2.8.2
  
  # Shared Preferences
  shared_preferences: ^2.2.2
  
  # State Management
  provider: ^6.1.1
  
  # UI Components
  cupertino_icons: ^1.0.6
```
