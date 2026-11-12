# Video Detail Screen - Implementazione

## Descrizione

Implementare schermata dettagli video che mostra metadati completi, thumbnail, e opzioni per riproduzione e download del video selezionato.

---

## Requisiti

### Informazioni da Mostrare

1. **Thumbnail Video**:
   - Immagine thumbnail grande e visibile
   - URL: `/api/videos/{video_id}/thumbnail`
   - Fallback a icona se thumbnail non disponibile

2. **Metadati Video**:
   - **Titolo**: Nome del video
   - **Descrizione**: Descrizione video (se disponibile)
   - **Durata**: Formattata (es. "1h 23m 45s")
   - **Risoluzione**: Width x Height (es. "1920x1080")
   - **Dimensione File**: Formattata (es. "5.0 GB")
   - **Formato**: File format (es. "mp4")
   - **Data Upload**: Data e ora upload formattata
   - **Status**: Stato video (ready, processing, error)

3. **Metadati Compressione** (se disponibili):
   - Risoluzione originale (se diversa da quella compressa)
   - Framerate originale e compresso
   - Dimensione file originale
   - Compression ratio (risparmio %)

4. **Metadati Tecnici** (se disponibili):
   - Codec video
   - Bitrate
   - Framerate

5. **Azioni Disponibili**:
   - **Riproduzione**: Pulsante per avviare riproduzione (future: streaming)
   - **Download**: Pulsante per scaricare video (future: download feature)

---

## Architettura

### Clean Architecture Layers

```
Presentation Layer
├── VideoDetailScreen (Screen)
└── VideoDetailViewModel (ViewModel)

Domain Layer
├── Video (Entity - già esistente)
├── VideoRepository (Interface - già esistente)
└── GetVideoByIdUseCase (UseCase - nuovo)

Data Layer
├── VideoRepositoryImpl (già esistente)
└── VideoRemoteDataSource.getVideoById() (già esistente)
```

---

## Implementazione

### 1. UseCase: GetVideoByIdUseCase

**File:** `lib/domain/usecases/get_video_by_id_usecase.dart` (nuovo)

```dart
import '../entities/video.dart';
import '../repositories/video_repository.dart';

/// Use case per ottenere dettagli video per ID
class GetVideoByIdUseCase {
  final VideoRepository repository;
  
  GetVideoByIdUseCase(this.repository);
  
  /// Esegue il recupero del video per ID
  /// 
  /// Args:
  ///   videoId: ID del video (UUID)
  /// 
  /// Returns:
  ///   Video entity con dettagli completi
  /// 
  /// Throws:
  ///   Exception se video non trovato o errore di rete
  Future<Video> execute(String videoId) async {
    return await repository.getVideoById(videoId);
  }
}
```

### 2. ViewModel: VideoDetailViewModel

**File:** `lib/features/video/viewmodels/video_detail_viewmodel.dart` (nuovo)

```dart
import 'package:flutter/foundation.dart';
import '../../../domain/entities/video.dart';
import '../../../domain/usecases/get_video_by_id_usecase.dart';

/// ViewModel per Video Detail Screen
class VideoDetailViewModel extends ChangeNotifier {
  final GetVideoByIdUseCase getVideoByIdUseCase;
  
  Video? _video;
  bool _isLoading = false;
  String? _error;
  
  VideoDetailViewModel(this.getVideoByIdUseCase);
  
  // Getters
  Video? get video => _video;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  
  /// Carica dettagli video per ID
  Future<void> loadVideo(String videoId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _video = await getVideoByIdUseCase.execute(videoId);
      _error = null;
    } catch (e) {
      _error = 'Failed to load video: $e';
      _video = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Refresh video details
  Future<void> refresh() async {
    if (_video != null) {
      await loadVideo(_video!.id);
    }
  }
}
```

### 3. Screen: VideoDetailScreen

**File:** `lib/presentation/screens/video/video_detail_screen.dart` (nuovo)

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/video.dart';
import '../../../features/video/viewmodels/video_detail_viewmodel.dart';
import '../../../domain/usecases/get_video_by_id_usecase.dart';
import '../../../data/repositories/video_repository_impl.dart';
import '../../../data/datasources/remote/video_remote_datasource.dart';
import '../../../core/network/api_client.dart';

/// Video Detail Screen - Presentation layer
class VideoDetailScreen extends StatefulWidget {
  final String videoId;
  
  const VideoDetailScreen({
    super.key,
    required this.videoId,
  });
  
  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  late VideoDetailViewModel _viewModel;
  
  @override
  void initState() {
    super.initState();
    _initializeViewModel();
    _loadVideo();
  }
  
  void _initializeViewModel() {
    final apiClient = ApiClient();
    final remoteDataSource = VideoRemoteDataSource(apiClient);
    final repository = VideoRepositoryImpl(remoteDataSource);
    final useCase = GetVideoByIdUseCase(repository);
    _viewModel = VideoDetailViewModel(useCase);
  }
  
  void _loadVideo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.loadVideo(widget.videoId);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Video Details'),
        ),
        body: Consumer<VideoDetailViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (viewModel.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${viewModel.error}',
                      style: TextStyle(color: Colors.red[700]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => viewModel.refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            
            if (viewModel.video == null) {
              return const Center(child: Text('Video not found'));
            }
            
            return _buildVideoDetails(viewModel.video!);
          },
        ),
      ),
    );
  }
  
  Widget _buildVideoDetails(Video video) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          _buildThumbnail(video),
          const SizedBox(height: 24),
          
          // Title
          Text(
            video.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Description (if available)
          if (video.description != null && video.description!.isNotEmpty) ...[
            Text(
              video.description!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Status badge
          _buildStatusBadge(video.status),
          const SizedBox(height: 24),
          
          // Metadata section
          _buildMetadataSection(video),
          const SizedBox(height: 24),
          
          // Compression info (if available)
          if (_hasCompressionInfo(video))
            _buildCompressionInfo(video),
          
          // Action buttons
          const SizedBox(height: 32),
          _buildActionButtons(video),
        ],
      ),
    );
  }
  
  Widget _buildThumbnail(Video video) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        height: 200,
        color: Colors.grey[300],
        child: video.thumbnailUrl != null
            ? Image.network(
                _buildThumbnailUrl(video.id),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildThumbnailPlaceholder();
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
              )
            : _buildThumbnailPlaceholder(),
      ),
    );
  }
  
  Widget _buildThumbnailPlaceholder() {
    return const Center(
      child: Icon(Icons.video_library, size: 64, color: Colors.grey),
    );
  }
  
  String _buildThumbnailUrl(String videoId) {
    // Costruisci URL thumbnail usando ApiConstants
    final baseUrl = 'http://your-server:8000'; // TODO: Usare ApiConstants
    return '$baseUrl/api/videos/$videoId/thumbnail';
  }
  
  Widget _buildStatusBadge(VideoStatus status) {
    Color color;
    String text;
    
    switch (status) {
      case VideoStatus.ready:
        color = Colors.green;
        text = 'Ready';
        break;
      case VideoStatus.processing:
        color = Colors.orange;
        text = 'Processing';
        break;
      case VideoStatus.error:
        color = Colors.red;
        text = 'Error';
        break;
      case VideoStatus.deleted:
        color = Colors.grey;
        text = 'Deleted';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
  
  Widget _buildMetadataSection(Video video) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Video Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildMetadataRow('Duration', _formatDuration(video.duration)),
            if (video.width != null && video.height != null)
              _buildMetadataRow('Resolution', '${video.width}x${video.height}'),
            _buildMetadataRow('File Size', _formatFileSize(video.fileSize)),
            _buildMetadataRow('Format', video.fileFormat.toUpperCase()),
            _buildMetadataRow('Uploaded', _formatDate(video.uploadedAt)),
            if (video.metadata != null && video.metadata!['codec'] != null)
              _buildMetadataRow('Codec', video.metadata!['codec'] as String),
            if (video.metadata != null && video.metadata!['bitrate'] != null)
              _buildMetadataRow(
                'Bitrate',
                _formatBitrate(video.metadata!['bitrate'] as int),
              ),
            if (video.metadata != null && video.metadata!['framerate'] != null)
              _buildMetadataRow(
                'Framerate',
                '${(video.metadata!['framerate'] as num).toStringAsFixed(1)} fps',
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompressionInfo(Video video) {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Compression Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (video.originalResolutionWidth != null &&
                video.originalResolutionHeight != null)
              _buildMetadataRow(
                'Original Resolution',
                '${video.originalResolutionWidth}x${video.originalResolutionHeight}',
              ),
            if (video.originalFramerate != null)
              _buildMetadataRow(
                'Original Framerate',
                '${video.originalFramerate!.toStringAsFixed(1)} fps',
              ),
            if (video.compressedFramerate != null)
              _buildMetadataRow(
                'Compressed Framerate',
                '${video.compressedFramerate!.toStringAsFixed(1)} fps',
              ),
            if (video.originalFileSize != null)
              _buildMetadataRow(
                'Original File Size',
                _formatFileSize(video.originalFileSize!),
              ),
            if (video.compressionRatio != null)
              _buildMetadataRow(
                'Compression Ratio',
                '${(video.compressionRatio! * 100).toStringAsFixed(1)}%',
              ),
          ],
        ),
      ),
    );
  }
  
  bool _hasCompressionInfo(Video video) {
    return video.originalResolutionWidth != null ||
        video.originalResolutionHeight != null ||
        video.originalFramerate != null ||
        video.compressedFramerate != null ||
        video.originalFileSize != null ||
        video.compressionRatio != null;
  }
  
  Widget _buildActionButtons(Video video) {
    return Row(
      children: [
        // Play button (future: streaming)
        Expanded(
          child: ElevatedButton.icon(
            onPressed: video.status == VideoStatus.ready
                ? () => _handlePlay(video)
                : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Download button (future: download feature)
        Expanded(
          child: OutlinedButton.icon(
            onPressed: video.status == VideoStatus.ready
                ? () => _handleDownload(video)
                : null,
            icon: const Icon(Icons.download),
            label: const Text('Download'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
  
  void _handlePlay(Video video) {
    // TODO: Implementare navigazione a player screen (streaming)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Play: ${video.title}')),
    );
  }
  
  void _handleDownload(Video video) {
    // TODO: Implementare download video
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Download: ${video.title}')),
    );
  }
  
  String _formatDuration(Duration? duration) {
    if (duration == null) return 'N/A';
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  String _formatBitrate(int bitrate) {
    if (bitrate < 1000) return '$bitrate bps';
    if (bitrate < 1000000) return '${(bitrate / 1000).toStringAsFixed(1)} Kbps';
    return '${(bitrate / 1000000).toStringAsFixed(1)} Mbps';
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
```

### 4. Navigazione da VideoListScreen

**File:** `lib/presentation/screens/video/video_list_screen.dart` (modificare)

```dart
void _navigateToVideoDetail(BuildContext context, Video video) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => VideoDetailScreen(videoId: video.id),
    ),
  );
}
```

---

## Flusso Completo

```
1. Utente clicca su video in VideoListScreen
   ↓
2. Navigazione a VideoDetailScreen con videoId
   ↓
3. VideoDetailScreen.initState() → Inizializza ViewModel
   ↓
4. VideoDetailViewModel.loadVideo(videoId)
   ↓
5. GetVideoByIdUseCase.execute(videoId)
   ↓
6. VideoRepository.getVideoById(videoId)
   ↓
7. VideoRemoteDataSource.getVideoById(videoId)
   ↓
8. API Call: GET /api/videos/{video_id}
   ↓
9. Server restituisce VideoResponse
   ↓
10. VideoResponse.toEntity() → Video entity
   ↓
11. ViewModel aggiorna stato (_video, _isLoading, _error)
   ↓
12. VideoDetailScreen rebuild con Consumer
   ↓
13. Mostra dettagli video, thumbnail, metadati, pulsanti
```

---

## Note Tecniche

### Thumbnail URL

- **URL Pattern**: `/api/videos/{video_id}/thumbnail`
- **Base URL**: Usare `ApiConstants` per costruire URL completo
- **Fallback**: Se thumbnail non disponibile, mostrare icona placeholder
- **Loading**: Mostrare `CircularProgressIndicator` durante caricamento

### Gestione Errori

- **404 Not Found**: Mostrare messaggio "Video not found" con pulsante retry
- **Network Error**: Mostrare messaggio errore con pulsante retry
- **Loading State**: Mostrare `CircularProgressIndicator` durante caricamento

### Metadati Opzionali

- Tutti i metadati sono opzionali (possono essere null)
- Mostrare solo metadati disponibili
- Usare "N/A" per valori mancanti dove appropriato

### Pulsanti Azione

- **Play**: Disabilitato se status != ready (TODO: implementare streaming)
- **Download**: Disabilitato se status != ready (TODO: implementare download)
- Per ora mostrano solo SnackBar (placeholder per future implementazioni)

### Performance

- Caricamento thumbnail lazy (con loading indicator)
- Metadati caricati una sola volta all'apertura screen
- Refresh disponibile tramite pull-to-refresh o pulsante retry

---

## Dipendenze

- **Provider**: Per state management (già presente nel progetto)
- **Nessun nuovo package richiesto**

---

## File da Creare/Modificare

### Nuovi File:
1. `lib/domain/usecases/get_video_by_id_usecase.dart`
2. `lib/features/video/viewmodels/video_detail_viewmodel.dart`
3. `lib/presentation/screens/video/video_detail_screen.dart`

### File da Modificare:
1. `lib/presentation/screens/video/video_list_screen.dart` (completare `_navigateToVideoDetail`)

### File Esistenti (già pronti):
- `lib/data/datasources/remote/video_remote_datasource.dart` (ha `getVideoById`)
- `lib/data/repositories/video_repository_impl.dart` (ha `getVideoById`)
- `lib/domain/repositories/video_repository.dart` (ha `getVideoById` interface)
- `lib/domain/entities/video.dart` (entity completa)
- `lib/data/models/video_response.dart` (con `toEntity()`)

