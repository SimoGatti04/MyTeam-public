# Ottimizzazione Android e Windows

## Problemi Identificati

### Android
1. **Compressione**: Più lenta e spesso fallisce
2. **Upload**: Più lento e spesso fallisce
3. **UI**: Problemi di rendering e performance

### Windows
- Da ottimizzare (piattaforma principale per utenti finali)

---

## Analisi Problemi Android

### 1. Compressione

**Problema**: MediaCodec su Android può essere più lento e instabile rispetto a VideoToolbox su macOS/iOS.

**Nota Importante**: Android **usa hardware acceleration** (MediaCodec) quando disponibile, simile a VideoToolbox su macOS/iOS. Tuttavia, MediaCodec ha limitazioni hardware-specifiche che possono causare problemi.

**Cause possibili**:
- MediaCodec ha limitazioni hardware-specifiche (non tutti i dispositivi supportano tutti i codec)
- Timeout troppo brevi per compressione lunga
- Mancanza di gestione errori specifica per Android
- Preset troppo aggressivo per hardware Android

**Soluzioni Implementate**:
- ✅ **Disabilitato MediaCodec su Android**: Ora usa sempre software encoding (`libx264`) che è più stabile e prevedibile
- ✅ **Progress tracking migliorato**: Su Android usa time-based progress invece di frame-based (più affidabile)
- ✅ **Timeout aumentato**: 2 ore invece di 1 ora per compressioni lunghe
- ✅ **Preset ottimizzato**: `veryfast` invece di `fast` per maggiore stabilità
- ⏳ **Retry logic**: Già presente in `compressVideoWithRetry`

### 2. Upload

**Problema**: Upload più lento e spesso fallisce su Android.

**Cause possibili**:
- Timeout di connessione troppo brevi
- Chunk size non ottimizzato per Android
- Problemi di rete mobile (interruzioni, cambio rete)
- Mancanza di retry logic robusta

**Soluzioni Implementate**:
- ✅ **Retry logic con exponential backoff**: 3 tentativi con delay 2, 4, 8 secondi
- ✅ **Timeout aumentati**: 60s per connessione, 24h per upload
- ✅ **Gestione errori migliorata**: Distingue tra errori retryable e non retryable
- ⏳ **Chunked upload**: Da implementare se necessario
- ⏳ **Rilevamento cambio rete**: Da implementare se necessario

### 3. UI

**Problema**: Problemi di rendering e performance su Android.

**Cause possibili**:
- Widget troppo pesanti (ListView con molti elementi)
- Animazioni non ottimizzate per Android
- Mancanza di lazy loading
- Memory leaks

**Soluzioni**:
- Usare `ListView.builder` con `cacheExtent` ottimizzato
- Implementare lazy loading per immagini/thumbnail
- Ottimizzare animazioni (usare `RepaintBoundary`)
- Aggiungere `AutomaticKeepAliveClientMixin` dove necessario
- Usare `const` constructors dove possibile

---

## Ottimizzazioni Implementate

### Compressione Android

```dart
// Aumentare timeout per Android (2 ore invece di 1)
final timeoutDuration = Platform.isAndroid 
    ? const Duration(hours: 2)
    : const Duration(hours: 1);

// Fallback a software encoding se MediaCodec fallisce
if (Platform.isAndroid && useHardware) {
  // Prova prima con MediaCodec
  // Se fallisce, retry con libx264 (software)
}

// Preset più veloce per Android
final preset = Platform.isAndroid 
    ? 'veryfast'  // Più veloce, meno qualità ma più stabile
    : 'fast';
```

### Upload Android

```dart
// Timeout più lunghi per Android
final connectTimeout = Platform.isAndroid
    ? const Duration(seconds: 60)  // 60s invece di 30s
    : const Duration(seconds: 30);

// Chunk size più piccolo per Android (retry più veloci)
final chunkSize = Platform.isAndroid
    ? 5 * 1024 * 1024  // 5MB invece di 10MB
    : 10 * 1024 * 1024;
```

### UI Android

```dart
// ListView ottimizzato
ListView.builder(
  cacheExtent: 250,  // Ridotto per Android
  itemBuilder: (context, index) {
    return RepaintBoundary(
      child: VideoListItem(video: videos[index]),
    );
  },
);

// Lazy loading immagini
Image.network(
  thumbnailUrl,
  loadingBuilder: (context, child, loadingProgress) {
    if (loadingProgress == null) return child;
    return const CircularProgressIndicator();
  },
  errorBuilder: (context, error, stackTrace) {
    return const Icon(Icons.error);
  },
);
```

---

## Video Player Nativi

### Situazione Attuale

**`video_player` package**:
- **Android**: Usa ExoPlayer (nativo) ✅
- **iOS**: Usa AVPlayer (nativo) ✅
- **macOS**: Usa AVPlayer (nativo) ✅
- **Windows**: Usa Media Foundation (nativo) ✅

**Conclusione**: `video_player` già usa player nativi per ogni piattaforma. Non serve cambiare.

### Alternative Considerate

1. **`better_player`**: Wrapper su `video_player` con funzionalità aggiuntive
   - Pro: Cache, subtitle, più controlli
   - Contro: Dipende da `video_player`, non risolve problemi base

2. **`fijkplayer`**: Player basato su ijkplayer (FFmpeg)
   - Pro: Più controllo, supporto formati estesi
   - Contro: Più complesso, meno mantenuto

3. **`chewie`**: UI wrapper su `video_player`
   - Pro: UI pre-costruita, facile da usare
   - Contro: Meno personalizzabile

**Raccomandazione**: Mantenere `video_player` e ottimizzare configurazione per Android.

---

## Ottimizzazioni Video Player Android

### Problema: "Source error, null null"

**Causa**: Video senza `faststart` flag (metadati non all'inizio).

**Soluzione**: Aggiunto `-movflags +faststart` nella compressione.

### Ottimizzazioni Aggiuntive

```dart
// Configurazione ottimizzata per ExoPlayer
VideoPlayerController.networkUrl(
  uri,
  videoPlayerOptions: VideoPlayerOptions(
    mixWithOthers: false,
    allowBackgroundPlayback: false,
  ),
  // Headers minimi - ExoPlayer gestisce automaticamente Range requests
  httpHeaders: {
    'User-Agent': 'MyTeam-Video-Player/1.0',
  },
);
```

---

## Ottimizzazioni Windows

### Compressione Windows

**Problema**: Windows non ha hardware acceleration nativa (no MediaCodec/VideoToolbox).

**Soluzione**: Usare software encoding (`libx264`) con preset ottimizzato.

```dart
// Windows: sempre software encoding
final useHardware = Platform.isIOS || Platform.isMacOS || Platform.isAndroid;
// Windows usa libx264 (software)

// Preset più veloce per Windows
final preset = Platform.isWindows
    ? 'veryfast'  // Più veloce
    : 'fast';
```

### Upload Windows

**Ottimizzazioni**:
- Timeout simili ad Android (60s connect, 24h upload)
- Chunk size ottimizzato (5MB)
- Retry logic robusta

### UI Windows

**Ottimizzazioni**:
- Stesse ottimizzazioni di Android
- Considerare `RepaintBoundary` per widget pesanti
- Lazy loading immagini

---

## Piano di Implementazione

### Fase 1: Compressione Android (Priorità Alta)
- [ ] Aumentare timeout per Android
- [ ] Aggiungere fallback a software encoding
- [ ] Ottimizzare preset per Android
- [ ] Aggiungere retry logic specifica

### Fase 2: Upload Android (Priorità Alta)
- [ ] Aumentare timeout connessione
- [ ] Implementare chunked upload con retry
- [ ] Aggiungere rilevamento cambio rete
- [ ] Ottimizzare chunk size

### Fase 3: UI Android (Priorità Media)
- [ ] Ottimizzare ListView
- [ ] Implementare lazy loading
- [ ] Aggiungere RepaintBoundary
- [ ] Usare const constructors

### Fase 4: Windows (Priorità Media)
- [ ] Applicare ottimizzazioni compressione
- [ ] Applicare ottimizzazioni upload
- [ ] Applicare ottimizzazioni UI

---

## Testing

### Android
1. Test compressione con video grandi (1GB+)
2. Test upload con rete instabile
3. Test UI con molti video (100+)
4. Test su dispositivi low-end

### Windows
1. Test compressione con video grandi
2. Test upload con rete instabile
3. Test UI con molti video
4. Test su Windows 10/11

---

## Metriche di Successo

### Compressione
- **Tempo**: < 2x tempo macOS per stesso video
- **Successo**: > 95% success rate
- **Memoria**: < 500MB durante compressione

### Upload
- **Velocità**: > 50% velocità macOS
- **Successo**: > 90% success rate
- **Retry**: < 3 retry per upload

### UI
- **FPS**: > 55 FPS durante scroll
- **Memoria**: < 200MB per lista video
- **Tempo caricamento**: < 2s per lista

---

## Note Tecniche

### MediaCodec Android

**IMPORTANTE**: MediaCodec è stato **disabilitato** su Android a causa di problemi di performance e stabilità.

**Motivazione**:
- MediaCodec è troppo lento su molti dispositivi Android
- Il progress tracking con MediaCodec è inaffidabile (si blocca a 0.5%)
- MediaCodec può fallire silenziosamente su dispositivi vecchi/low-end
- Software encoding (`libx264`) è più stabile e prevedibile

**Soluzione Implementata**: 
- ✅ **Software encoding sempre**: Android usa sempre `libx264` (software) invece di MediaCodec
- ✅ **Progress tracking time-based**: Su Android usa tempo invece di frame (più affidabile)
- ✅ **Preset ottimizzato**: `veryfast` per maggiore velocità
- ✅ **Timeout aumentato**: 2 ore invece di 1 ora per compressioni lunghe

**Nota**: Software encoding è più lento ma molto più stabile e affidabile su Android.

### ExoPlayer Android

**Configurazione**:
- Richiede metadati all'inizio (`faststart`)
- Supporta automaticamente Range requests
- Gestisce buffering automaticamente

**Ottimizzazioni**:
- Headers minimi
- Timeout appropriati
- Error handling robusto

---

## Riferimenti

- [ExoPlayer Documentation](https://exoplayer.dev/)
- [MediaCodec Guide](https://developer.android.com/reference/android/media/MediaCodec)
- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices)
- [video_player Package](https://pub.dev/packages/video_player)

