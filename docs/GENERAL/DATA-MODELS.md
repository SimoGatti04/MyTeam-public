# Modelli Logici e Data Models

## Entity Models (Domain Layer)

### Video Entity
```dart
class Video {
  final String id;
  final String title;
  final String? description;
  final String fileName;
  final int fileSize; // bytes
  final String fileFormat; // mp4, avi, etc.
  final Duration? duration;
  final int? width;
  final int? height;
  final String? thumbnailUrl;
  final DateTime uploadedAt;           // Data di aggiunta (non modificabile)
  final DateTime? recordedAt;           // Data di realizzazione (modificabile, estratta da metadati o impostata manualmente)
  final DateTime? lastModifiedAt;
  final VideoStatus status; // processing, ready, error
  final Map<String, dynamic>? metadata; // codec, bitrate, etc.
  
  // Compression metadata (client-side compression)
  final int? originalResolutionWidth;  // Risoluzione originale prima compressione
  final int? originalResolutionHeight;
  final double? originalFramerate;  // Framerate originale prima compressione
  final double? compressedFramerate;  // Framerate compresso scelto dall'utente
  final int? originalFileSize;  // Dimensione originale prima compressione (bytes)
  final double? compressionRatio;  // Risparmio % (0.0-1.0, es: 0.75 = 75% risparmio)
  
  // Relazioni con Tag, Giocatori, Squadre, Note
  final List<String>? playerIds;        // Riferimenti a giocatori taggati
  final List<String>? trainingTypeIds;  // Riferimenti a tipi di allenamento/esercizi
  final List<String>? teamIds;          // Riferimenti a squadre taggate
  final List<String>? noteIds;          // Riferimenti a note associate
}

enum VideoStatus {
  processing,
  ready,
  error,
  deleted
}
```

### UploadTask Entity
```dart
class UploadTask {
  final String id;
  final String? videoId; // null se non ancora creato
  final String localFilePath;
  final String remoteFileName;
  final int totalBytes;
  final int uploadedBytes;
  final UploadStatus status;
  final double progress; // 0.0 - 1.0
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  
  // CopyWith method per aggiornare stato
  UploadTask copyWith({...});
}

enum UploadStatus {
  queued,      // In coda (non ancora iniziato)
  compressing, // Compressione in corso
  uploading,   // Upload in corso
  completed,   // Completato con successo
  error,       // Errore durante upload
  cancelled    // Cancellato dall'utente
}
```

### DownloadTask Entity
```dart
class DownloadTask {
  final String id;
  final String videoId;
  final String localSavePath;
  final int totalBytes;
  final int downloadedBytes;
  final DownloadStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? errorMessage;
  final double progress; // 0.0 - 1.0
}

enum DownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
  cancelled
}
```

### StreamingSession Entity
```dart
class StreamingSession {
  final String videoId;
  final String streamUrl;
  final Duration? currentPosition;
  final bool isPlaying;
  final double? playbackSpeed;
  final DateTime? lastWatchedAt;
}
```

### Tag Entity (Generico - Opzionale)
```dart
// Tag generici opzionali per categorizzazione libera
// I tag specifici (Player, TrainingType, Team) sono preferiti per organizzazione strutturata
class Tag {
  final String id;
  final String name;
  final String? description;
  final String? color; // hex color per UI
  final DateTime createdAt;
  final int videoCount; // numero video associati
}

class VideoTag {
  final String id;
  final String videoId;
  final String tagId;
  final DateTime taggedAt;
}
```

### Player Entity (Giocatore)
```dart
class Player {
  final String id;
  final String name;                   // Nome completo (es: "Mario Rossi")
  final String? description;            // Note aggiuntive (opzionale)
  final String? photoUrl;              // Foto profilo (opzionale)
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int videoCount;                // Numero video associati (calcolato)
}

class VideoPlayer {
  final String id;
  final String videoId;
  final String playerId;
  final DateTime taggedAt;             // Quando è stato taggato
}
```

### TrainingType Entity (Tipo di Allenamento/Esercizio)
```dart
class TrainingType {
  final String id;
  final String name;                   // Nome tipo (es: "Riscaldamento", "Tecnica", "Partita")
  final String? description;           // Descrizione dettagliata (opzionale)
  final String? category;              // Categoria (es: "Riscaldamento", "Esercizio", "Partita")
  final String? color;                 // Colore per UI (hex, opzionale)
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int videoCount;                // Numero video associati (calcolato)
}

class VideoTrainingType {
  final String id;
  final String videoId;
  final String trainingTypeId;
  final DateTime taggedAt;
}
```

### Team Entity (Squadra)
```dart
class Team {
  final String id;
  final String name;                   // Nome squadra (es: "Prima Squadra", "Under 19")
  final String? description;           // Descrizione (opzionale)
  final String? logoUrl;               // Logo squadra (opzionale)
  final String? color;                 // Colore per UI (hex, opzionale)
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int videoCount;                // Numero video associati (calcolato)
}

class VideoTeam {
  final String id;
  final String videoId;
  final String teamId;
  final DateTime taggedAt;
}
```

### Action Entity (Future)
```dart
class Action {
  final String id;
  final String videoId;
  final String actionType; // es: "jump", "goal", "event", etc.
  final String? description;
  final Duration timestamp; // quando avviene nel video
  final Map<String, dynamic>? metadata; // dati aggiuntivi
  final DateTime createdAt;
}

enum ActionType {
  custom,
  goal,
  event,
  highlight,
  // altri tipi da definire
}
```

### Note Entity
```dart
class Note {
  final String id;
  final String videoId;
  final String content;                // Contenuto nota (testo)
  final Duration? timestamp;            // Timestamp nel video (opzionale, se nota è relativa a un momento specifico)
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isPrivate;                // Sempre true per app privata, ma utile per organizzazione
}
```

## Data Models (Data Layer - DTOs)

### API Response Models

```dart
// API Video Response (corrisponde a VideoResponse Pydantic schema)
class VideoResponse {
  final String id;
  final String title;
  final String? description;
  final String filename;
  final String filePath;
  final int fileSize;
  final String fileFormat;
  final int? duration; // seconds (not durationSeconds)
  final int? width;
  final int? height;
  final String? thumbnailPath; // not thumbnailUrl
  final String status; // "processing", "ready", "error"
  final Map<String, dynamic>? videoMetadata; // not metadata
  final int? originalResolutionWidth;
  final int? originalResolutionHeight;
  final double? originalFramerate;
  final double? compressedFramerate;
  final int? originalFileSize;
  final double? compressionRatio;
  final DateTime createdAt; // not uploadedAt
  final DateTime updatedAt; // not lastModifiedAt
  
  // Mapper to Video Entity
  Video toEntity() { ... }
}
```

**Nota:** I nomi dei campi corrispondono esattamente al Pydantic schema `VideoResponse` del server:
- `filename` (non `fileName`)
- `filePath` (non `file_path` in Dart)
- `duration` in secondi (non `durationSeconds`)
- `thumbnailPath` (non `thumbnailUrl`)
- `videoMetadata` (non `metadata`)
- `createdAt` e `updatedAt` come DateTime (non stringhe ISO)

// API Upload Init Response
class UploadInitResponse {
  final String uploadId;
  final String uploadUrl;
  final int chunkSize; // se chunked upload
}

// API Download Response (per streaming)
class StreamResponse {
  final String streamUrl;
  final String? hlsUrl; // se HLS supportato
  final Map<String, String>? qualityOptions;
}
```

### Local Storage Models

```dart
// SQLite Cache Model
class CachedVideo {
  final String id;
  final String title;
  final String fileName;
  final int fileSize;
  final String? thumbnailPath; // path locale
  final DateTime cachedAt;
  final DateTime? lastAccessedAt;
}

// Settings Model
class AppSettings {
  final String serverUrl; // obbligatorio, configurazione server
  final bool autoSync;
  final String? downloadPath;
  final int maxConcurrentUploads;
  final int maxConcurrentDownloads;
  final VideoQuality preferredStreamingQuality;
}

enum VideoQuality {
  auto,
  low,    // 360p
  medium, // 720p
  high,   // 1080p
  original
}
```

## Relazioni Logiche

### Phase 1: Core Video
```
Video (1) ──── (N) UploadTask
  │                  │
  │                  │
  └──────────────────┘
  Video can have multiple upload attempts

Video (1) ──── (N) DownloadTask
  │                    │
  │                    │
  └────────────────────┘
  Video can be downloaded multiple times

Video (1) ──── (1) StreamingSession
  │                      │
  │                      │
  └──────────────────────┘
  One active streaming session per video
```

### Phase 2: Organizzazione Video (Tag, Giocatori, Squadre, Note)
```
Video (N) ──── (M) Player
  │                    │
  │                    │
  └────────────────────┘
  Many-to-Many: Video can have multiple players tagged

Video (N) ──── (M) TrainingType
  │                    │
  │                    │
  └────────────────────┘
  Many-to-Many: Video can have multiple training types/exercises tagged

Video (N) ──── (M) Team
  │                    │
  │                    │
  └────────────────────┘
  Many-to-Many: Video can have multiple teams tagged

Video (1) ──── (N) Note
  │                    │
  │                    │
  └────────────────────┘
  One-to-Many: Video can have multiple notes
  (with optional timestamp in video)
```

## Data Flow Models

### Upload Flow
```
Local File Selection
    │
    ├─> Validate File (size, format)
    │
    ├─> Extract Metadata (durata, risoluzione)
    │
    ├─> Create UploadTask
    │
    ├─> Initialize Upload (API call)
    │       │
    │       └─> Get Upload URL/Token
    │
    ├─> Chunk Upload (if large file)
    │       │
    │       └─> Progress Updates
    │
    └─> Complete Upload
            │
            └─> Create Video Entity
```

### Download Flow
```
Video Selection
    │
    ├─> Check Local Cache
    │       │
    │       └─> If exists: Use cached
    │
    ├─> Create DownloadTask
    │
    ├─> Start Download (API call)
    │       │
    │       └─> Get Download URL
    │
    ├─> Chunk Download
    │       │
    │       └─> Progress Updates
    │
    └─> Save to Local Storage
            │
            └─> Update Cache
```

### Streaming Flow
```
Video Selection
    │
    ├─> Get Stream URL (API call)
    │
    ├─> Initialize Player
    │
    ├─> Load Stream
    │       │
    │       └─> Buffer Management
    │
    ├─> Playback Control
    │       │
    │       ├─> Play/Pause
    │       ├─> Seek
    │       └─> Volume Control
    │
    └─> Save Position (periodicamente)
            │
            └─> Update Last Watched
```

## State Models

### UI State Models

```dart
// Video List State
class VideoListState {
  final List<Video> videos;
  final bool isLoading;
  final String? error;
  final String? searchQuery;
  final VideoSortOption sortOption;
}

enum VideoSortOption {
  uploadedAtAsc,      // Data aggiunta crescente
  uploadedAtDesc,     // Data aggiunta decrescente
  recordedAtAsc,       // Data realizzazione crescente
  recordedAtDesc,      // Data realizzazione decrescente
  titleAsc,            // Nome A-Z
  titleDesc,           // Nome Z-A
  playerAsc,           // Primo giocatore A-Z
  playerDesc,          // Primo giocatore Z-A
  trainingTypeAsc,     // Primo tipo allenamento A-Z
  trainingTypeDesc,    // Primo tipo allenamento Z-A
  teamAsc,             // Squadra A-Z
  teamDesc,            // Squadra Z-A
  sizeAsc,             // Dimensione crescente
  sizeDesc,            // Dimensione decrescente
}

// Upload State
class UploadState {
  final List<UploadTask> activeUploads;
  final List<UploadTask> completedUploads;
  final bool isUploading;
}

// Download State
class DownloadState {
  final List<DownloadTask> activeDownloads;
  final List<DownloadTask> completedDownloads;
  final bool isDownloading;
}

// Player State
class PlayerState {
  final Video? currentVideo;
  final bool isPlaying;
  final Duration currentPosition;
  final Duration totalDuration;
  final bool isBuffering;
  final double playbackSpeed;
}
```

## Validazione e Regole di Business

### Video Upload Rules
- File size limit: Da definire (es: max 10GB)
- Supported formats: MP4, AVI, MOV, MKV, WebM
- Metadata extraction: Automatica se possibile
- Concurrent uploads: Max 3 simultanei (configurabile)

### Download Rules
- Storage check: Verifica spazio disponibile prima del download
- Concurrent downloads: Max 5 simultanei (configurabile)
- Resume capability: Supporto per resume su interruzioni

### Streaming Rules
- Auto quality: Adattamento in base a bandwidth disponibile
- Buffer size: Ottimizzato per ridurre buffering
- Position save: Salva ogni 10 secondi di riproduzione

