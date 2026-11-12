# Miglioramenti Cancellazione Upload e Compressione

## Problema Identificato

1. **Upload**: Quando si preme "Annulla", l'upload sparisce momentaneamente ma continua in background
2. **Compressione**: La cancellazione non sempre termina completamente il processo FFmpeg su Windows
3. **Log**: I log non vengono mostrati nell'overlay debug quando attivo

## Soluzioni Implementate

### 1. Sistema di Cancellazione Upload (Dio CancelToken)

**File creati:**
- `lib/core/services/upload_cancellation_service.dart`

**Funzionalità:**
- Traccia tutte le richieste HTTP di upload attive
- Crea `CancelToken` per ogni upload
- Permette cancellazione immediata della richiesta HTTP
- Supporta cancellazione singola o multipla

**Integrazione:**
- `UploadRemoteDataSource`: Accetta `CancelToken` nelle richieste
- `UploadRepository`: Passa `CancelToken` al datasource
- `UploadViewModel`: Crea e gestisce `CancelToken` per ogni upload
- `cancelUpload()`: Ora cancella anche la richiesta HTTP, non solo il task

### 2. Cancellazione Compressione Migliorata (Windows)

**Modifiche a `video_compression_service.dart`:**

**Prima:**
```dart
process?.kill();
```

**Dopo:**
```dart
// 1. Kill normale
process.kill();

// 2. Attendi 500ms
await Future.delayed(Duration(milliseconds: 500));

// 3. Se ancora attivo, kill forzato con timeout
final exitCode = await process.exitCode.timeout(
  Duration(seconds: 1),
  onTimeout: () {
    process.kill(ProcessSignal.sigkill);
    return -1;
  },
);

// 4. Se ancora non termina, termina tutti i processi FFmpeg
if (Platform.isWindows) {
  await Process.run('taskkill', ['/F', '/IM', 'ffmpeg.exe', '/T']);
}
```

**Risultato:**
- Kill più aggressivo e affidabile
- Fallback a `taskkill` se necessario
- Termina anche processi figlio (`/T` flag)

### 3. Sistema Logging Unificato (DebugLogger)

**File creati:**
- `lib/core/services/debug_logger.dart`
- `lib/presentation/widgets/debug_log_overlay.dart`

**Funzionalità:**
- Buffer circolare (max 500 log)
- Listener per aggiornamenti in tempo reale
- Colori per livello (ERROR=rosso, WARN=arancione, DEBUG=blu)
- Overlay minimizzabile/massimizzabile
- Pulsante clear per pulire log

**Sostituzioni:**
- `debugPrint()` → `DebugLogger.info/warning/error/debug()`
- Tutti i log ora appaiono nell'overlay quando debug mode è attiva

**File modificati:**
- `lib/main.dart`: Errori globali → DebugLogger
- `lib/features/upload/viewmodels/upload_viewmodel.dart`: Log upload → DebugLogger
- `lib/features/upload/services/video_compression_service.dart`: Log compressione → DebugLogger
- `lib/data/datasources/remote/upload_remote_datasource.dart`: Log upload → DebugLogger

### 4. Cancellazione Upload Completa

**Flusso di cancellazione:**

1. **Utente preme "Annulla"**
2. **UploadViewModel.cancelUpload():**
   - Se in compressione → `VideoCompressionService.cancelCompression()`
   - Se in upload → `UploadCancellationService.cancelUpload()` (cancella HTTP)
   - Aggiorna stato task → `cancelled`
   - Resetta `_currentUploadTask`

3. **Risultato:**
   - Richiesta HTTP viene cancellata immediatamente
   - Processo FFmpeg viene terminato (Windows: kill aggressivo)
   - Task viene marcato come `cancelled`
   - UI aggiornata immediatamente

## Testing

### Test Cancellazione Upload

1. Avvia upload di un file grande (>100MB)
2. Dopo qualche secondo, premi "Annulla"
3. **Verifica:**
   - Upload si ferma immediatamente
   - Task scompare dalla lista
   - Nessun upload continua in background
   - Log mostrano "Upload cancelled"

### Test Cancellazione Compressione

1. Avvia compressione di un video grande
2. Durante compressione, premi "Annulla"
3. **Verifica:**
   - Compressione si ferma immediatamente
   - Processo FFmpeg viene terminato
   - Task scompare dalla lista
   - Log mostrano "Compression cancelled"

### Test Debug Logger

1. Vai su Settings → Attiva "Debug Mode"
2. Avvia upload/compressione
3. **Verifica:**
   - Overlay appare in fondo allo schermo
   - Log vengono mostrati in tempo reale
   - Colori corretti per livello
   - Pulsante clear funziona

## Note Tecniche

### CancelToken Dio

- `CancelToken` viene creato all'inizio di ogni upload
- Viene passato a tutte le richieste Dio (normale e chunked)
- Quando cancellato, Dio interrompe immediatamente la richiesta HTTP
- Non c'è bisogno di attendere timeout

### Kill Processo Windows

- `process.kill()`: Termina processo normalmente
- `process.kill(ProcessSignal.sigkill)`: Forza terminazione
- `taskkill /F /IM ffmpeg.exe /T`: Termina tutti i processi FFmpeg e figli
- `/F` = Force, `/IM` = Image name, `/T` = Tree (include figli)

### Debug Logger

- Buffer circolare mantiene solo ultimi 500 log
- Listener pattern per aggiornamenti UI
- Thread-safe (usa Queue)
- Performance: O(1) per aggiunta, O(n) per lettura

## Future Miglioramenti

1. **Chunked Upload Cancellation**: Implementare cancellazione anche per chunked upload
2. **Retry Cancellation**: Se upload è in retry, cancellare anche i retry
3. **Cleanup File**: Cancellare file compresso se upload viene cancellato
4. **Log Export**: Esportare log in file per debugging

