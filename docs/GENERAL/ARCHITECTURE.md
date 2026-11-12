# Architettura del Sistema

## Architettura Client-Server

```
┌─────────────────────────────────────────┐
│         CLIENT (Flutter App)            │
│  ┌───────────────────────────────────┐  │
│  │      Presentation Layer            │  │
│  │  (Screens, Widgets, ViewModels)    │  │
│  └───────────────────────────────────┘  │
│              │                           │
│  ┌───────────────────────────────────┐  │
│  │       Domain Layer                 │  │
│  │  (Business Logic, Entities,       │  │
│  │   Use Cases, Repositories Intf)   │  │
│  └───────────────────────────────────┘  │
│              │                           │
│  ┌───────────────────────────────────┐  │
│  │        Data Layer                 │  │
│  │  (Repositories Impl, Data Sources,│  │
│  │   Models, Cache, Local Storage)   │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
              │
        HTTP/WebSocket
              │
┌─────────────────────────────────────────┐
│         SERVER (Backend API)            │
│  ┌───────────────────────────────────┐  │
│  │      REST API                      │  │
│  │  - Video Management                │  │
│  │  - Streaming Endpoints             │  │
│  │  - Tag & Metadata Endpoints        │  │
│  └───────────────────────────────────┘  │
│              │                           │
│  ┌───────────────────────────────────┐  │
│  │      Business Logic Layer         │  │
│  │  - File Processing                 │  │
│  │  - Streaming Logic                 │  │
│  │  - Video Metadata Extraction       │  │
│  │  - Tag & Metadata Management       │  │
│  └───────────────────────────────────┘  │
│              │                           │
│  ┌───────────────────────────────────┐  │
│  │      Data/Persistence Layer       │  │
│  │  - Database (Video Metadata, Tags,│  │
│  │     Persons, Actions, Notes)      │  │
│  │  - File Storage (Video Files)     │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## Architettura Flutter (Clean Architecture)

### Layer Structure

1. **Presentation Layer**
   - UI Components (Widgets)
   - State Management (Provider/Bloc/Riverpod)
   - ViewModels/Controllers
   - Navigation

2. **Domain Layer**
   - Business Entities (pure Dart classes)
   - Use Cases (business logic)
   - Repository Interfaces
   - Domain Exceptions

3. **Data Layer**
   - Repository Implementations
   - Remote Data Sources (API calls)
   - Local Data Sources (SQLite, SharedPreferences)
   - Data Models (DTOs)
   - Cache Management

4. **Core Layer**
   - Shared Utilities
   - Constants
   - Extensions
   - Error Handling
   - Network Configuration

## Pattern Utilizzati

- **Clean Architecture**: Separazione delle responsabilità
- **Repository Pattern**: Astrazione dell'accesso ai dati
- **Dependency Injection**: Gestione delle dipendenze
- **State Management**: Provider/Bloc/Riverpod (da decidere)
- **MVVM**: Model-View-ViewModel nel Presentation Layer

## Flusso Dati Tipico

```
User Action
    │
    ├─> ViewModel/Controller
    │       │
    │       └─> Use Case
    │               │
    │               └─> Repository Interface
    │                       │
    │                       └─> Repository Implementation
    │                               │
    │                               ├─> Remote Data Source (API)
    │                               └─> Local Data Source (Cache/DB)
    │
    └─> State Update ─> UI Rebuild
```

## Componenti Principali

### Client-Side

1. **Video Service**
   - Upload Management
   - Download Management
   - Streaming Controller
   - Metadata Management

2. **Video Organization Service**
   - Player (Giocatore) Management
   - TrainingType (Tipo Allenamento/Esercizio) Management
   - Team (Squadra) Management
   - Notes Management
   - Video Tagging (Players, TrainingTypes, Teams)
   - Date Management (recorded_date extraction and editing)

3. **Storage Service**
   - Local File Management
   - Cache Management
   - Settings Persistence

4. **Network Service**
   - HTTP Client Configuration
   - Retry Logic
   - Error Handling
   - Server URL Configuration

### Server-Side (Da Implementare - Priorità)

#### Phase 1: Core Video Functionality
1. **Video API**
   - Upload endpoints (multipart)
   - Download endpoints
   - List/Search endpoints
   - Metadata extraction endpoints
   - Video deletion

2. **Streaming API**
   - Progressive download
   - Range requests support (HTTP 206)
   - Video serving endpoint (video compresso ricevuto)
   - NO transcoding server-side (per ora)

3. **File Storage**
   - Video file storage management (video compresso ricevuto)
   - Thumbnail generation (opzionale)
   - Metadata extraction (durata, risoluzione, codec)
   - Compression metadata storage

#### Phase 2: Video Organization System
4. **Player API**
   - Create/Update/Delete players
   - Player-video associations
   - Player search and filtering

5. **TrainingType API**
   - Create/Update/Delete training types
   - TrainingType-video associations
   - TrainingType search and filtering

6. **Team API**
   - Create/Update/Delete teams
   - Team-video associations
   - Team search and filtering

7. **Note API**
   - Create/Update/Delete notes
   - Note-video associations (with optional timestamp)
   - Note search

8. **Video Filtering & Sorting API**
   - Filter by date (month, season, week, day, custom range)
   - Filter by players, training types, teams
   - Sort by various criteria (date, name, players, etc.)
   - Combined filters support

5. **Person API**
   - Person management
   - Person-video associations
   - Person search

6. **Action API**
   - Action tracking
   - Action-video associations
   - Action timeline

7. **Notes API**
   - Note creation/editing
   - Note-video associations
   - Note search

## Considerazioni Tecniche

### Networking
- **HTTP Client**: `dio` o `http` package
- **Streaming**: `video_player` package con supporto HTTP range requests
- **Upload/Download**: Chunked upload per file grandi, progress callbacks

### Local Storage
- **Settings**: `shared_preferences`
- **Cache Metadata**: SQLite (`sqflite`)
- **Video Cache**: File system diretto

### State Management
- Da decidere: Provider, Bloc, Riverpod, o GetX

### Dependency Injection
- `get_it` o `injectable`

## Sicurezza (Semplificata per App Privata)

1. **Transport Security**
   - HTTPS consigliato ma non obbligatorio per uso locale
   - HTTP accettabile per rete locale/trusted
   - Certificate pinning non necessario

2. **Access Control**
   - Nessuna autenticazione richiesta
   - Accesso diretto al server (configurazione server URL nell'app)
   - Possibilità di limitare accesso a IP specifici lato server (opzionale)

3. **Data Protection**
   - Storage locale: File system diretto
   - Cache locale: SQLite con dati non sensibili

