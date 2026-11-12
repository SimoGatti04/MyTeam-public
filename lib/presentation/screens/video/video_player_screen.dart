import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
// Windows: usa media_kit per video player
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as media_kit_video;
import '../../../core/constants/api_constants.dart';
import '../../../domain/entities/video.dart';
import '../../../core/services/debug_logger.dart';

/// Video Player Screen - Riproduzione video con controlli nativi
class VideoPlayerScreen extends StatefulWidget {
  final Video video;

  const VideoPlayerScreen({
    super.key,
    required this.video,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  // Windows: usa media_kit
  Player? _mediaKitPlayer;
  media_kit_video.VideoController? _mediaKitVideoController;
  
  // Altre piattaforme: usa video_player
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Posticipa l'inizializzazione del player dopo il build phase
    // Questo evita errori "setState() called during build" con DebugLogOverlay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePlayer();
    });
  }

  void _initializePlayer() async {
    try {
      // Costruisci URL streaming
      final streamUrl = ApiConstants.videoStream(widget.video.id);

      // Debug: stampa URL per troubleshooting
      DebugLogger.info('🎬 [VideoPlayer] Inizializzazione player con URL: $streamUrl');

      // Verifica che l'URL sia valido
      final uri = Uri.parse(streamUrl);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        throw Exception('URL non valido: $streamUrl');
      }

      // Su macOS: verifica che il video sia accessibile prima di inizializzare
      if (Platform.isMacOS) {
        DebugLogger.info('🔍 [VideoPlayer macOS] Verifica accessibilità video...');
        try {
          final client = HttpClient();
          final request = await client.headUrl(uri).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Timeout durante verifica accessibilità video');
            },
          );
          final response = await request.close();
          DebugLogger.info('✅ [VideoPlayer macOS] Video accessibile (status: ${response.statusCode})');
          if (response.statusCode != 200 && response.statusCode != 206) {
            throw Exception('Video non accessibile (status: ${response.statusCode})');
          }
          client.close();
        } catch (e) {
          DebugLogger.warning('⚠️ [VideoPlayer macOS] Verifica accessibilità fallita: $e');
          DebugLogger.info('🔄 [VideoPlayer macOS] Procedo comunque con inizializzazione...');
        }
      }

      // Windows: usa media_kit
      if (Platform.isWindows) {
        await _initializeMediaKit(streamUrl);
      } else {
        // Altre piattaforme: usa video_player
        await _initializeVideoPlayer(uri);
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }
    } catch (e, stackTrace) {
      DebugLogger.error('❌ [VideoPlayer] Errore inizializzazione: $e');
      DebugLogger.debug('   Stack: $stackTrace');

      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Errore caricamento video: ${e.toString()}';
        });
      }
    }
  }
  
  /// Inizializza media_kit per Windows
  Future<void> _initializeMediaKit(String streamUrl) async {
    // Inizializza media_kit (solo una volta)
    MediaKit.ensureInitialized();
    
    // Crea player con configurazione base
    // Nota: media_kit usa mpv come backend
    // Per problemi di lettura su Windows, usiamo configurazione base senza hardware acceleration
    _mediaKitPlayer = Player();
    
    // Apri video con opzioni per streaming HTTP
    // Media_kit gestisce automaticamente Range requests e streaming
    await _mediaKitPlayer!.open(
      Media(streamUrl),
      play: false, // Non avviare automaticamente, aspetta comando utente
    );
    
    // Crea video controller con configurazione ottimizzata per Windows
    // Disabilita hardware acceleration per maggiore compatibilità
    // Hardware acceleration può causare problemi di lettura su alcuni sistemi Windows
    _mediaKitVideoController = media_kit_video.VideoController(
      _mediaKitPlayer!,
      configuration: media_kit_video.VideoControllerConfiguration(
        // Disabilita hardware acceleration per compatibilità
        // Su Windows, hardware acceleration può causare problemi di lettura video
        // Software rendering è più compatibile e stabile
        enableHardwareAcceleration: false,
      ),
    );
    
    DebugLogger.info('✅ [VideoPlayer Windows] MediaKit inizializzato con successo');
    DebugLogger.debug('   URL: $streamUrl');
    DebugLogger.debug('   Configurazione: Software rendering (compatibilità Windows)');
  }
  
  /// Inizializza video_player per altre piattaforme
  Future<void> _initializeVideoPlayer(Uri uri) async {
    DebugLogger.info('🎬 [VideoPlayer macOS] Inizio inizializzazione video_player');
    DebugLogger.debug('   URL: $uri');
    
    // Crea controller video player con configurazione ottimizzata
    _videoPlayerController = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
        allowBackgroundPlayback: false,
      ),
      httpHeaders: {
        'User-Agent': 'MyTeam-Video-Player/1.0',
      },
    );

    // Aggiungi listener per lo stato del player (per debugging)
    _videoPlayerController!.addListener(() {
      if (_videoPlayerController!.value.hasError) {
        DebugLogger.error('❌ [VideoPlayer macOS] Errore player: ${_videoPlayerController!.value.errorDescription}');
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = _videoPlayerController!.value.errorDescription ?? 'Errore sconosciuto';
          });
        }
      } else if (_videoPlayerController!.value.isInitialized) {
        DebugLogger.info('✅ [VideoPlayer macOS] Player inizializzato');
        DebugLogger.debug('   Durata: ${_videoPlayerController!.value.duration}');
        DebugLogger.debug('   Risoluzione: ${_videoPlayerController!.value.size}');
        DebugLogger.debug('   Aspect ratio: ${_videoPlayerController!.value.aspectRatio}');
      } else {
        DebugLogger.debug('🔄 [VideoPlayer macOS] Player in caricamento...');
      }
    });

    DebugLogger.info('🔄 [VideoPlayer macOS] Chiamata initialize()...');
    
    // Inizializza player con timeout più lungo per macOS (60 secondi)
    // macOS potrebbe richiedere più tempo per processare video compressi
    try {
      await _videoPlayerController!.initialize().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          DebugLogger.error('❌ [VideoPlayer macOS] Timeout durante inizializzazione (60s)');
          throw Exception('Timeout durante inizializzazione video player (60 secondi)');
        },
      );
      
      DebugLogger.info('✅ [VideoPlayer macOS] initialize() completato');
    } catch (e) {
      DebugLogger.error('❌ [VideoPlayer macOS] Errore durante initialize(): $e');
      rethrow;
    }

    // Verifica che il video sia stato caricato correttamente
    if (!_videoPlayerController!.value.isInitialized) {
      DebugLogger.error('❌ [VideoPlayer macOS] Player non inizializzato dopo initialize()');
      throw Exception('Video player non inizializzato correttamente');
    }

    DebugLogger.info('🎬 [VideoPlayer macOS] Creazione ChewieController...');

    // Crea Chewie controller con controlli nativi
    // Su Windows, usa configurazione specifica per evitare problemi aspect ratio
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController!,
      autoPlay: false,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      allowPlaybackSpeedChanging: true,
      showControls: true,
      // Su Windows: usa aspectRatio esplicito per evitare fasce nere mobili
      aspectRatio: Platform.isWindows 
          ? _videoPlayerController!.value.aspectRatio 
          : null, // Altre piattaforme: auto
      // Controlli nativi per ogni piattaforma
      materialProgressColors: ChewieProgressColors(
        playedColor: Colors.red,
        bufferedColor: Colors.white.withOpacity(0.5),
        backgroundColor: Colors.white.withOpacity(0.3),
        handleColor: Colors.red,
      ),
      placeholder: Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
      errorBuilder: (context, errorMessage) {
        DebugLogger.error('❌ [VideoPlayer macOS] Chewie error: $errorMessage');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Errore riproduzione',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );

    DebugLogger.info('✅ [VideoPlayer macOS] Player inizializzato con successo');
    DebugLogger.debug('   Durata: ${_videoPlayerController!.value.duration}');
    DebugLogger.debug('   Risoluzione: ${_videoPlayerController!.value.size}');
    DebugLogger.debug('   Aspect ratio: ${_videoPlayerController!.value.aspectRatio}');
  }

  @override
  void dispose() {
    // Windows: dispose media_kit
    if (Platform.isWindows) {
      _mediaKitPlayer?.dispose();
      // VideoController non ha dispose(), viene gestito automaticamente dal Player
      _mediaKitVideoController = null;
    } else {
      // Altre piattaforme: dispose video_player
      _chewieController?.dispose();
      _videoPlayerController?.dispose();
    }
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            widget.video.title,
            style: const TextStyle(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: _hasError
            ? _buildErrorView()
            : !_isInitialized || (Platform.isWindows ? _mediaKitVideoController == null : _chewieController == null)
                ? _buildLoadingView()
                : _buildPlayerView(),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Caricamento video...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Errore caricamento video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Errore sconosciuto',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _isInitialized = false;
                });
                if (Platform.isWindows) {
                  _mediaKitPlayer?.dispose();
                  _mediaKitVideoController = null;
                } else {
                  _chewieController?.dispose();
                  _videoPlayerController?.dispose();
                }
                _initializePlayer();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
            const SizedBox(height: 16),
            // Mostra URL per debug
            if (kDebugMode)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SelectableText(
                  'URL: ${ApiConstants.videoStream(widget.video.id)}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerView() {
    // Windows: usa media_kit
    if (Platform.isWindows) {
      if (_mediaKitVideoController == null) {
        return _buildLoadingView();
      }
      // Media_kit gestisce aspect ratio internamente con Fill.contain
      // Usa Container nero per sfondo e lascia che Video widget gestisca il rendering
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Center(
          child: media_kit_video.Video(controller: _mediaKitVideoController!),
        ),
      );
    }
    
    // Altre piattaforme: usa video_player/chewie
    if (_chewieController == null || _videoPlayerController == null) {
      return _buildLoadingView();
    }

    // Per video_player/chewie: usa Container con aspect ratio fisso
    // Questo risolve il problema delle fasce nere mobili su Windows (se usassimo video_player)
    final aspectRatio = _videoPlayerController!.value.aspectRatio;
    if (aspectRatio.isNaN || aspectRatio <= 0) {
      // Fallback se aspect ratio non valido
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Center(
          child: Chewie(controller: _chewieController!),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Chewie(controller: _chewieController!),
        ),
      ),
    );
  }
}
