# Video Streaming - Implementazione

## Descrizione

Implementazione dello streaming video per riproduzione diretta senza download completo del file. Il sistema supporta HTTP Range requests (HTTP 206) per streaming efficiente.

---

## Architettura

### Server (FastAPI)

**Endpoint**: `GET /api/videos/{video_id}/stream`

**Caratteristiche**:
- Supporto HTTP Range requests (HTTP 206 Partial Content)
- Streaming efficiente con chunk di 8KB
- Headers corretti per video streaming
- Validazione video e file esistenza
- Supporto per vari formati video (MP4, AVI, MOV, MKV, WebM)

**Implementazione**:
```python
@router.get("/api/videos/{video_id}/stream")
async def stream_video(
    video_id: str,
    request: Request,
    db: Session = Depends(get_db),
    range: Optional[str] = Header(None),
):
    # Verifica video esiste e status ready
    # Verifica file esiste
    # Supporta Range requests per streaming efficiente
    # Restituisce StreamingResponse con chunk del file
```

**Range Requests**:
- Client invia header `Range: bytes=start-end`
- Server risponde con HTTP 206 (Partial Content)
- Headers: `Content-Range`, `Accept-Ranges`, `Content-Length`
- Streaming chunk-based per efficienza memoria

### App (Flutter)

**Screen**: `VideoPlayerScreen`

**Caratteristiche**:
- Player video con supporto streaming automatico
- Controlli: play, pause, seek, volume
- Progress bar interattiva
- Gestione errori e loading states
- UI responsive con overlay controlli

**Package**: `video_player: ^2.8.2`

**Implementazione**:
```dart
class VideoPlayerScreen extends StatefulWidget {
  final Video video;
  
  // Inizializza VideoPlayerController.networkUrl
  // Supporta automaticamente HTTP Range requests
  // Gestisce play, pause, seek, volume
}
```

---

## Flusso Streaming

### 1. Inizializzazione

1. Utente clicca "Play" in `VideoDetailScreen`
2. Navigazione a `VideoPlayerScreen` con video selezionato
3. Costruzione URL streaming: `/api/videos/{video_id}/stream`
4. Inizializzazione `VideoPlayerController.networkUrl()`

### 2. Caricamento Video

1. `VideoPlayerController` invia richiesta HTTP al server
2. Server verifica video e file esistenza
3. Server restituisce file completo o porzione (se Range header presente)
4. Player inizia buffering video

### 3. Riproduzione

1. Player gestisce automaticamente Range requests per seek
2. Server risponde con chunk richiesti (HTTP 206)
3. Player riproduce video in streaming
4. Controlli UI permettono play, pause, seek

### 4. Seek (Cambio Posizione)

1. Utente interagisce con progress bar
2. Player calcola nuova posizione
3. Player invia nuova Range request al server
4. Server restituisce chunk dalla nuova posizione
5. Player riprende riproduzione dalla nuova posizione

---

## File Implementati

### Server

**File**: `server/app/api/routes/videos.py`

**Funzione**: `stream_video()`

**Caratteristiche**:
- Verifica video esiste e status `ready`
- Verifica file esiste su disco
- Supporto Range requests completo
- Streaming chunk-based (8KB chunks)
- Headers corretti per video streaming
- Gestione errori (404, 416)

### App

**File**: `lib/presentation/screens/video/video_player_screen.dart`

**Classe**: `VideoPlayerScreen`

**Caratteristiche**:
- Inizializzazione player con URL streaming
- Gestione stati: loading, error, playing
- Controlli UI: play/pause, seek, progress
- Overlay controlli con tap per mostrare/nascondere
- Gestione errori con retry

**File**: `lib/presentation/screens/video/video_detail_screen.dart`

**Modifiche**:
- Sostituito placeholder `_handlePlay()` con navigazione a `VideoPlayerScreen`
- Import `VideoPlayerScreen`

---

## API Endpoint

### GET /api/videos/{video_id}/stream

**Descrizione**: Stream video con supporto Range requests

**Parametri**:
- `video_id` (path): ID video (UUID)

**Headers**:
- `Range` (opzionale): Range header per richiedere porzione file (es: `bytes=0-1023`)

**Response**:
- **200 OK**: File completo (se Range header non presente)
- **206 Partial Content**: Porzione file richiesta (se Range header presente)
- **404 Not Found**: Video o file non trovato
- **400 Bad Request**: Video non ready per streaming
- **416 Range Not Satisfiable**: Range invalido

**Headers Response**:
- `Content-Type`: Media type video (es: `video/mp4`)
- `Accept-Ranges`: `bytes`
- `Content-Length`: Dimensione file o chunk
- `Content-Range`: Range bytes restituiti (solo per 206)

**Esempio Request**:
```http
GET /api/videos/123e4567-e89b-12d3-a456-426614174000/stream HTTP/1.1
Host: localhost:8000
Range: bytes=0-1048575
```

**Esempio Response (206)**:
```http
HTTP/1.1 206 Partial Content
Content-Type: video/mp4
Accept-Ranges: bytes
Content-Range: bytes 0-1048575/52428800
Content-Length: 1048576
```

---

## UI/UX

### VideoPlayerScreen

**Layout**:
- Schermo nero fullscreen
- Video centrato con aspect ratio corretto
- Overlay controlli con gradiente trasparente
- AppBar con titolo video e back button

**Controlli**:
- **Play/Pause**: Icona grande centrale (tap per toggle)
- **Progress Bar**: Interattiva, permette seek
- **Time Display**: Posizione corrente e durata totale
- **Auto-hide Controls**: Tap su video per mostrare/nascondere controlli

**Stati**:
- **Loading**: CircularProgressIndicator con messaggio
- **Error**: Icona errore, messaggio, pulsante retry
- **Playing**: Video player con controlli overlay

**Gestione Errori**:
- Mostra messaggio errore chiaro
- Pulsante "Riprova" per re-inizializzare player
- Fallback graceful se video non disponibile

---

## Performance

### Server

**Ottimizzazioni**:
- Streaming chunk-based (8KB) per efficienza memoria
- Range requests per evitare download completo
- File reading efficiente con seek
- Headers corretti per caching browser

**Limiti**:
- Nessun limite di dimensione file (gestito da storage)
- Chunk size: 8KB (bilanciato memoria/velocità)
- Connessioni simultanee: limitate da FastAPI/uvicorn

### App

**Ottimizzazioni**:
- `VideoPlayerController` gestisce automaticamente buffering
- Range requests automatiche per seek efficiente
- Lazy loading: player inizializzato solo quando necessario
- Dispose corretto per liberare risorse

**Limiti**:
- Dipende da connessione network
- Buffering automatico gestito da `video_player` package
- Memoria: gestita automaticamente dal player

---

## Compatibilità

### Formati Video Supportati

**Server**:
- MP4 (video/mp4) ✅
- AVI (video/x-msvideo) ✅
- MOV (video/quicktime) ✅
- MKV (video/x-matroska) ✅
- WebM (video/webm) ✅

**App**:
- Dipende da `video_player` package
- Supporta formati supportati da piattaforma nativa
- iOS: Formati supportati da AVPlayer
- Android: Formati supportati da ExoPlayer

### Piattaforme

**Server**: 
- Qualsiasi piattaforma con Python 3.8+ e FastAPI

**App**:
- iOS ✅ (AVPlayer nativo)
- Android ✅ (ExoPlayer nativo)
- macOS ✅ (AVPlayer nativo)
- Windows ✅ (Media Foundation nativo)

**Nota**: `video_player` già usa player nativi per ogni piattaforma. Non serve cambiare package.

---

## Testing

### Test Manuale

1. **Streaming Base**:
   - Seleziona video dalla lista
   - Clicca "Play" in VideoDetailScreen
   - Verifica player si apre e carica video
   - Verifica video riproduce correttamente

2. **Controlli**:
   - Verifica play/pause funziona
   - Verifica seek funziona (drag progress bar)
   - Verifica time display aggiorna correttamente
   - Verifica controlli si nascondono/mostrano con tap

3. **Error Handling**:
   - Testa con video non esistente (404)
   - Testa con video status != ready (400)
   - Testa con connessione network interrotta
   - Verifica messaggi errore chiari

4. **Range Requests**:
   - Usa browser DevTools per verificare Range requests
   - Verifica HTTP 206 responses
   - Verifica seek invia nuove Range requests

### Test Automatici (Future)

- Unit tests per endpoint server
- Integration tests per streaming flow
- Widget tests per VideoPlayerScreen
- E2E tests per streaming completo

---

## Note Tecniche

### HTTP Range Requests

**Formato Range Header**:
- `bytes=start-end`: Range specifico (es: `bytes=0-1023`)
- `bytes=start-`: Da posizione a fine file (es: `bytes=1024-`)
- `bytes=-suffix`: Ultimi N bytes (es: `bytes=-1024`)

**Response Headers**:
- `Content-Range: bytes start-end/total`: Range restituito
- `Accept-Ranges: bytes`: Indica supporto Range requests
- `Content-Length`: Dimensione chunk restituito

### Video Player Package

**VideoPlayerController.networkUrl()**:
- Supporta automaticamente HTTP Range requests
- Gestisce buffering automatico
- Supporta seek efficiente
- Gestisce errori network automaticamente

**VideoPlayerOptions**:
- `mixWithOthers: false`: Non mixa audio con altre app
- Altre opzioni disponibili per personalizzazione

---

## Future Miglioramenti

### Adaptive Streaming (HLS/DASH)

**Possibilità**:
- Implementare HLS (HTTP Live Streaming) per qualità multiple
- Implementare DASH (Dynamic Adaptive Streaming)
- Server-side transcoding per generare varianti qualità

**Vantaggi**:
- Qualità adattiva basata su bandwidth
- Migliore esperienza utente
- Streaming più fluido

### Caching

**Possibilità**:
- Cache locale per video parzialmente scaricati
- Resume playback da cache
- Prefetch intelligente

**Vantaggi**:
- Riduzione bandwidth
- Riproduzione più veloce
- Supporto offline parziale

### Controlli Avanzati

**Possibilità**:
- Volume control
- Playback speed (0.5x, 1x, 1.5x, 2x)
- Picture-in-picture (PiP)
- Fullscreen mode

**Vantaggi**:
- Migliore UX
- Più opzioni per utente
- Esperienza più completa

---

## File Modificati/Creati

### Server
- ✅ `server/app/api/routes/videos.py`: Aggiunto endpoint `stream_video()`

### App
- ✅ `lib/presentation/screens/video/video_player_screen.dart`: Nuovo file
- ✅ `lib/presentation/screens/video/video_detail_screen.dart`: Modificato `_handlePlay()`

### Documentazione
- ✅ `docs/APP/DECISIONS/video-streaming.md`: Questo file

---

## Riferimenti

- [FastAPI StreamingResponse](https://fastapi.tiangolo.com/advanced/custom-response/#streamingresponse)
- [HTTP Range Requests (RFC 7233)](https://tools.ietf.org/html/rfc7233)
- [video_player package](https://pub.dev/packages/video_player)
- [VideoPlayerController API](https://pub.dev/documentation/video_player/latest/video_player/VideoPlayerController-class.html)

