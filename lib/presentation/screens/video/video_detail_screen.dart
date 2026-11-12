import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/video.dart';
import '../../../features/video/viewmodels/video_detail_viewmodel.dart';
import '../../../domain/usecases/get_video_by_id_usecase.dart';
import '../../../domain/usecases/update_video_title_usecase.dart';
import '../../../data/repositories/video_repository_impl.dart';
import '../../../data/datasources/remote/video_remote_datasource.dart';
import '../../../data/datasources/remote/note_remote_datasource.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../domain/entities/note.dart';
import '../../widgets/player_management_dialog.dart';
import '../../widgets/training_type_management_dialog.dart';
import '../../widgets/team_management_dialog.dart';
import 'video_player_screen.dart';

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
  late NoteRemoteDataSource _noteDataSource;
  final TextEditingController _notesController = TextEditingController();
  List<Note> _notes = [];
  bool _isSavingNote = false;
  bool _notesLoaded = false; // Flag per evitare caricamenti multipli
  String? _currentNoteId; // ID della nota principale (se esiste)
  
  @override
  void initState() {
    super.initState();
    _initializeViewModel();
    _initializeNoteDataSource();
    _loadVideo();
  }
  
  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
  
  void _initializeNoteDataSource() {
    final apiClient = ApiClient();
    _noteDataSource = NoteRemoteDataSource(apiClient);
  }
  
  void _initializeViewModel() {
    final apiClient = ApiClient();
    final remoteDataSource = VideoRemoteDataSource(apiClient);
    final repository = VideoRepositoryImpl(remoteDataSource);
    final getVideoUseCase = GetVideoByIdUseCase(repository);
    final updateTitleUseCase = UpdateVideoTitleUseCase(repository);
    _viewModel = VideoDetailViewModel(
      getVideoUseCase,
      updateVideoTitleUseCase: updateTitleUseCase,
    );
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        'Error: ${viewModel.error}',
                        style: TextStyle(color: Colors.red[700]),
                        textAlign: TextAlign.center,
                      ),
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
            
            // Carica note quando il video è disponibile (solo una volta)
            if (!_notesLoaded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_notesLoaded) {
                  _loadNotes(viewModel.video!.id);
                }
              });
            }
            
            return _buildVideoDetails(context, viewModel.video!);
          },
        ),
      ),
    );
  }
  
  Future<void> _loadNotes(String videoId) async {
    if (_notesLoaded) return; // Evita caricamenti multipli
    
    try {
      final notes = await _noteDataSource.getVideoNotes(videoId);
      if (mounted) {
        setState(() {
          _notes = notes;
          _notesLoaded = true;
          // Se c'è una nota principale, caricala nel campo
          if (notes.isNotEmpty) {
            // Per semplicità, prendiamo la prima nota o quella più recente
            final mainNote = notes.first;
            _currentNoteId = mainNote.id;
            _notesController.text = mainNote.content;
          } else {
            _currentNoteId = null;
            _notesController.clear();
          }
        });
      }
    } catch (e) {
      // Errore nel caricamento note - ignora per non bloccare la UI
      if (mounted) {
        setState(() {
          _notesLoaded = true; // Segna come caricato anche in caso di errore
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load notes: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  Future<void> _saveNote(String videoId) async {
    if (_isSavingNote) return;
    
    final content = _notesController.text.trim();
    if (content.isEmpty) {
      // Se il contenuto è vuoto e c'è una nota esistente, eliminala
      if (_currentNoteId != null) {
        try {
          await _noteDataSource.deleteNote(videoId, _currentNoteId!);
          setState(() {
            _currentNoteId = null;
            _notes.clear();
          });
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete note: $e')),
            );
          }
        }
      }
      return;
    }
    
    setState(() {
      _isSavingNote = true;
    });
    
    try {
      if (_currentNoteId != null) {
        // Aggiorna nota esistente
        final updatedNote = await _noteDataSource.updateNote(
          videoId: videoId,
          noteId: _currentNoteId!,
          content: content,
        );
        setState(() {
          final index = _notes.indexWhere((n) => n.id == _currentNoteId!);
          if (index != -1) {
            _notes[index] = updatedNote;
          } else {
            _notes = [updatedNote];
          }
        });
      } else {
        // Crea nuova nota
        final newNote = await _noteDataSource.createNote(
          videoId: videoId,
          content: content,
        );
        setState(() {
          _currentNoteId = newNote.id;
          _notes = [newNote];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save note: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSavingNote = false;
      });
    }
  }
  
  Widget _buildVideoDetails(BuildContext context, Video video) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          _buildThumbnail(video),
          const SizedBox(height: 24),
          
          // Title with edit button
          Row(
            children: [
              Expanded(
                child: Text(
                  video.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showEditTitleDialog(context, video),
                tooltip: 'Edit title',
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Recorded date (modificabile)
          if (video.recordedAt != null) ...[
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Data realizzazione: ${_formatDate(video.recordedAt!)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _showEditRecordedDateDialog(context, video),
                  child: const Text('Modifica'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Data realizzazione: Non impostata',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _showEditRecordedDateDialog(context, video),
                  child: const Text('Imposta'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          
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
          
          // Organization tags (Players, TrainingTypes, Teams)
          _buildOrganizationSection(context, video),
          const SizedBox(height: 24),
          
          // Notes section (prominente)
          _buildNotesSection(context, video),
          const SizedBox(height: 24),
          
          // Metadata section (espandibile, nascosta di default)
          _buildExpandableMetadataSection(video),
          const SizedBox(height: 16),
          
          // Compression info (espandibile, nascosta di default, se disponibile)
          if (_hasCompressionInfo(video))
            _buildExpandableCompressionInfo(video),
          
          // Action buttons
          const SizedBox(height: 32),
          _buildActionButtons(context, video),
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
    // ApiConstants.videoThumbnail già include il baseUrl
    return ApiConstants.videoThumbnail(videoId);
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
  
  Widget _buildExpandableMetadataSection(Video video) {
    return Card(
      child: ExpansionTile(
        title: const Text(
          'Video Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: const Icon(Icons.info_outline, size: 20),
        initiallyExpanded: false,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
        ],
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
  
  Widget _buildExpandableCompressionInfo(Video video) {
    return Card(
      color: Colors.blue[50],
      child: ExpansionTile(
        title: const Text(
          'Compression Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: const Icon(Icons.compress, size: 20),
        initiallyExpanded: false,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
        ],
      ),
    );
  }
  
  Widget _buildNotesSection(BuildContext context, Video video) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.note, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Note',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isSavingNote) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 8,
              minLines: 4,
              decoration: const InputDecoration(
                hintText: 'Aggiungi note libere per questo video...',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              textCapitalization: TextCapitalization.sentences,
              onChanged: (text) {
                // Debounce save - salva dopo 2 secondi di inattività
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted && _notesController.text == text) {
                    _saveNote(video.id);
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              _isSavingNote
                  ? 'Salvataggio in corso...'
                  : 'Le note vengono salvate automaticamente',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _showEditRecordedDateDialog(BuildContext context, Video video) async {
    // Mostra dialog con opzioni
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Data Realizzazione'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (video.recordedAt != null)
              Text('Data attuale: ${_formatDate(video.recordedAt!)}'),
            const SizedBox(height: 16),
            const Text('Scegli un\'azione:'),
          ],
        ),
        actions: [
          if (video.recordedAt != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop('remove'),
              child: const Text('Rimuovi', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('select'),
            child: const Text('Seleziona Data'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
        ],
      ),
    );
    
    if (action == null || !mounted) return;
    
    DateTime? selectedDate;
    
    if (action == 'remove') {
      selectedDate = DateTime(1970, 1, 1); // Special value per rimuovere
    } else if (action == 'select') {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: video.recordedAt ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        helpText: 'Seleziona data realizzazione',
      );
      if (pickedDate != null) {
        selectedDate = pickedDate;
      } else {
        return; // Utente ha annullato
      }
    } else {
      return;
    }
    
    if (selectedDate != null && mounted) {
      try {
        final apiClient = ApiClient();
        final remoteDataSource = VideoRemoteDataSource(apiClient);
        
        // Se selectedDate è DateTime(1970, 1, 1), rimuovi la data
        // Altrimenti normalizza con 12:00:00 UTC per evitare problemi di fuso orario
        final recordedDate = selectedDate.year == 1970 
            ? null 
            : DateTime.utc(selectedDate.year, selectedDate.month, selectedDate.day, 12, 0, 0);
        
        await remoteDataSource.updateVideo(
          id: video.id,
          recordedDate: recordedDate,
        );
        
        // Ricarica video per aggiornare UI
        _viewModel.refresh();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(recordedDate == null 
                  ? 'Data realizzazione rimossa'
                  : 'Data realizzazione aggiornata'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update recorded date: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  bool _hasCompressionInfo(Video video) {
    return video.originalResolutionWidth != null ||
        video.originalResolutionHeight != null ||
        video.originalFramerate != null ||
        video.compressedFramerate != null ||
        video.originalFileSize != null ||
        video.compressionRatio != null;
  }
  
  Widget _buildActionButtons(BuildContext context, Video video) {
    return Column(
      children: [
        Row(
          children: [
            // Play button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: video.status == VideoStatus.ready
                    ? () => _handlePlay(context, video)
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
                    ? () => _handleDownload(context, video)
                    : null,
                icon: const Icon(Icons.download),
                label: const Text('Download'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Delete button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showDeleteConfirmation(context, video),
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text('Delete Video', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }
  
  Future<void> _showDeleteConfirmation(BuildContext context, Video video) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Video'),
        content: Text(
          'Are you sure you want to delete "${video.title}"?\n\n'
          'This action cannot be undone. The video file and all associated data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && context.mounted) {
      await _deleteVideo(context, video);
    }
  }
  
  Future<void> _deleteVideo(BuildContext context, Video video) async {
    final viewModel = context.read<VideoDetailViewModel>();
    
    // Mostra loading
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deleting video...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    try {
      // TODO: Implementare deleteVideo nel VideoDetailViewModel
      // Per ora, usiamo direttamente il repository
      final apiClient = ApiClient();
      final remoteDataSource = VideoRemoteDataSource(apiClient);
      await remoteDataSource.deleteVideo(video.id);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Naviga alla lista video
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _handlePlay(BuildContext context, Video video) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(video: video),
      ),
    );
  }
  
  void _handleDownload(BuildContext context, Video video) {
    // Download video - feature da implementare in futuro
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Download: ${video.title}')),
    );
  }
  
  /// Mostra dialog per editare il titolo video
  Future<void> _showEditTitleDialog(BuildContext context, Video video) async {
    final titleController = TextEditingController(text: video.title);
    final viewModel = context.read<VideoDetailViewModel>();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Video Title'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Title',
            hintText: 'Enter video title',
            border: OutlineInputBorder(),
          ),
          maxLength: 255,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newTitle = titleController.text.trim();
              if (newTitle.isNotEmpty && newTitle != video.title) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      final newTitle = titleController.text.trim();
      if (newTitle.isNotEmpty && newTitle != video.title) {
        // Mostra loading
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Updating title...'),
              duration: Duration(seconds: 1),
            ),
          );
        }
        
        // Aggiorna titolo
        final success = await viewModel.updateTitle(newTitle);
        
        if (context.mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Title updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update title: ${viewModel.error}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
    
    titleController.dispose();
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
    // Mostra solo la data senza orario
    return '${date.day}/${date.month}/${date.year}';
  }
  
  Widget _buildOrganizationSection(BuildContext context, Video video) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Organizzazione',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Players section
            _buildTagSection(
              context,
              'Giocatori',
              Icons.person,
              video.playerIds ?? [],
              () => _showPlayerManagementDialog(context, video),
            ),
            const SizedBox(height: 16),
            
            // Training Types section
            _buildTagSection(
              context,
              'Tipo Allenamento',
              Icons.fitness_center,
              video.trainingTypeIds ?? [],
              () => _showTrainingTypeManagementDialog(context, video),
            ),
            const SizedBox(height: 16),
            
            // Teams section
            _buildTagSection(
              context,
              'Squadra',
              Icons.group,
              video.teamIds ?? [],
              () => _showTeamManagementDialog(context, video),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTagSection(
    BuildContext context,
    String title,
    IconData icon,
    List<String> tagIds,
    VoidCallback onManage,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onManage,
              child: const Text('Gestisci'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (tagIds.isEmpty)
          Text(
            'Nessun $title associato',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                '${tagIds.length} ${title.toLowerCase()} associati',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
      ],
    );
  }
  
  Future<void> _showPlayerManagementDialog(BuildContext context, Video video) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => PlayerManagementDialog(
        videoId: video.id,
        currentPlayerIds: video.playerIds ?? [],
      ),
    );
    
    if (result == true && mounted) {
      // Ricarica video per aggiornare UI
      _viewModel.refresh();
    }
  }
  
  Future<void> _showTrainingTypeManagementDialog(BuildContext context, Video video) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => TrainingTypeManagementDialog(
        videoId: video.id,
        currentTrainingTypeIds: video.trainingTypeIds ?? [],
      ),
    );
    
    if (result == true && mounted) {
      // Ricarica video per aggiornare UI
      _viewModel.refresh();
    }
  }
  
  Future<void> _showTeamManagementDialog(BuildContext context, Video video) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => TeamManagementDialog(
        videoId: video.id,
        currentTeamIds: video.teamIds ?? [],
      ),
    );
    
    if (result == true && mounted) {
      // Ricarica video per aggiornare UI
      _viewModel.refresh();
    }
  }
}

