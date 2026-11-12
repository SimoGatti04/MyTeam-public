# Architettura App Flutter

## Clean Architecture

```
┌─────────────────────────────────────────┐
│      Presentation Layer                 │
│  - Screens                              │
│  - Widgets                              │
│  - ViewModels/Controllers               │
│  - State Management                     │
└─────────────────────────────────────────┘
              │
┌─────────────────────────────────────────┐
│      Domain Layer                       │
│  - Entities (pure Dart classes)         │
│  - Use Cases (business logic)           │
│  - Repository Interfaces                │
│  - Domain Exceptions                    │
└─────────────────────────────────────────┘
              │
┌─────────────────────────────────────────┐
│      Data Layer                         │
│  - Repository Implementations            │
│  - Remote Data Sources (API calls)      │
│  - Local Data Sources (SQLite, Files)   │
│  - Data Models (DTOs)                   │
│  - Cache Management                     │
└─────────────────────────────────────────┘
```

---

## Layer Structure

### Presentation Layer

**Screens:**
- Video list screen
- Video detail screen
- Upload screen
- Compression settings screen
- Download progress screen
- Streaming player screen

**Widgets:**
- Video list item
- Video player widget
- Progress indicator
- Compression settings widget

**ViewModels:**
- Upload view model ✅ (implementato)
- Video list view model (future)
- Download view model (future)
- Streaming view model (future)

### Domain Layer

**Entities:**
- Video ✅ (implementato)
- UploadTask ✅ (implementato)
- CompressionSettings ✅ (implementato)
- DownloadTask (future)
- StreamingSession (future)

**Use Cases:**
- UploadVideoUseCase ✅ (implementato)
- GetVideosUseCase (future)
- DownloadVideoUseCase (future)
- StreamVideoUseCase (future)

**Repository Interfaces:**
- VideoRepository
- UploadRepository
- DownloadRepository

### Data Layer

**Repositories:**
- UploadRepositoryImpl ✅ (implementato)
- VideoRepositoryImpl (future)
- DownloadRepositoryImpl (future)

**Data Sources:**
- UploadRemoteDataSource ✅ (implementato)
- VideoRemoteDataSource (future)
- VideoLocalDataSource (future - SQLite cache)
- FileLocalDataSource (future - file system)

**Models:**
- VideoResponse ✅ (API DTO - implementato)
- VideoEntity (domain entity - è `Video`)

---

## Pattern Utilizzati

### Repository Pattern
- Astrazione accesso dati
- Separazione remote/local sources
- Cache management

### Dependency Injection
- `get_it` o `injectable`
- Service locator pattern

### State Management
- **Provider** ✅ (implementato)
  - ViewModel con ChangeNotifier
  - Provider per dependency injection

---

## Core Services Implementati

### ConnectivityService
- Verifica connessione internet prima degli upload
- Stream di cambiamenti di connettività
- Gestione errori di connessione

### VideoMetadataService
- Estrazione metadata usando FFprobe
- Parsing JSON output
- Estrazione: duration, resolution, framerate, codec, bitrate

### VideoCompressionService
- Compressione video usando FFmpeg
- Retry automatico (max 5 tentativi)
- Stima dimensione file compresso
- Supporto risoluzioni: 480p, 720p, 1080p, 1440p, 2160p, Original
- Supporto framerate: 24, 30, 60, 120 fps

## Stato Implementazione

**Fase 1 (Upload) - ✅ Completato:**
- Domain layer completo per upload
- Data layer completo per upload
- Compression client-side
- Upload UI con progress tracking
- Connectivity check
- Error handling con retry

**Fase 2 (List/Download/Streaming) - 🔄 Future:**
- Video list screen
- Download functionality
- Streaming functionality

Per architettura generale client-server, vedere `GENERAL/ARCHITECTURE.md`.

