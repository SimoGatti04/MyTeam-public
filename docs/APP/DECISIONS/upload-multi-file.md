# Decisione: Multi Upload & Folder Support

**Data:** 2025-01-15  
**Stato:** 🚧 In implementazione

---

## Panoramica

Estendere la schermata Upload per:

1. **Selezionare più file contemporaneamente** (multi-select)
2. **Selezionare intere cartelle** (traversal ricorsivo, estrae solo file video validi)
3. **Gestire ogni file come task indipendente**
4. **Continuare upload/compressione anche se un file fallisce**
5. **Mostrare stato dettagliato per ogni task (queued, scanning, compressing, uploading, completed, error)**

**IMPORTANTE:** Le cartelle non vengono mantenute sul server. Ogni file viene caricato singolarmente direttamente nella cartella `videos` di storage, senza preservare la struttura delle cartelle originali.

---

## Requisiti

### Formati supportati (validazione client-side)
- Estensioni consentite: `mp4`, `mov`, `mkv`, `avi`, `webm`
- File nascosti ignorati (`.` prefix)
- File duplicati (stesso path) scartati automaticamente
- Dimensione file <= `AppConstants.maxUploadSize`

### Selezione File
- Pulsante `Select Files` usa `FilePicker.platform.pickFiles(allowMultiple: true)`
- Limite di selezione configurabile (`AppConstants.maxFilesPerBatch`, default 50)
- UI mostra anteprima dei file selezionati prima di avviare il batch

### Selezione Cartelle
- Pulsante `Select Folder` usa `FilePicker.platform.getDirectoryPath()`
- Scansione ricorsiva (profondità massima configurabile, default 3)
- Mostrare stato scanning (`Scanning folder... (12 files found)`)
- Filtrare automaticamente file non supportati

### Coda Upload
- Ogni file diventa un `UploadSubTask`
- I sub-task vivono dentro un `UploadBatch`
- Stati possibili:
  - `queued`
  - `scanning` (solo folder)
  - `compressing`
  - `uploading`
  - `completed`
  - `error`
- Un fallimento NON blocca il batch
- Concorrenza configurabile (`AppConstants.maxConcurrentUploads`, default 2). Se 0 => sequenziale.

### Feedback UI
- Nuova sezione `Upload Queue` con lista task
- Ogni task:
  - Nome file
  - Stato
  - Progress bar doppia (compressione + upload) o progress combinato
  - Icone rapide (cancel, retry)
- Sezione `Completed` (ultimi 20 task con filtro success/error)
- Snackbar riepilogo a fine batch (X completati, Y falliti)

### Retry & Cancel
- Pulsante `Retry` per task falliti
- Pulsante `Cancel` per task attivi (ferma compressione/upload e pulisce file temporanei)
- Pulsante `Clear Completed` (già esistente) deve gestire più task

---

## Architettura

### Domain Layer
- **Nuova Entity:** `UploadBatch`
  - `id`
  - `files`: lista di `UploadSubTask`
  - `status`: `pending`, `running`, `completed`, `partial`
  - `createdAt`, `completedAt`
- **Update `UploadTask`:**
  - Aggiungere `batchId`
  - Aggiungere `stage`: `preparing`, `compressing`, `uploading`
  - Aggiungere `failureReason`
- **Nuovi Use Case:**
  - `CreateUploadBatchUseCase`
  - `StartUploadBatchUseCase`
  - `RetryUploadTaskUseCase`
  - (Riutilizzare `UploadVideoUseCase` per ogni sub-task)

### Data Layer
- **Local Data Source (SharedPreferences)**
  - Salvare stato batch + task (JSON compatto)
  - Persistenza di `queued` + `running` + ultimi `N` completati
- **Repository**
  - Gestire `batch -> tasks`
  - Esporre stream o callback per aggiornamenti progress
  - Coordinare concorrenza (limite max)

### Presentation Layer

#### UploadViewModel
- Nuovi stati:
  - `_batches`
  - `_activeTasks` (lista flatten)
  - `_folderScanProgress`
- Metodi:
  - `pickFilesMulti()`
  - `pickFolder()`
  - `startBatch(UploadBatch batch)`
  - `retryTask(UploadTask task)`
  - `cancelTask(UploadTask task)`
  - `cancelAllQueued()`
- Gestione concorrenza:
  - Scheduler interno (Queue + `maxConcurrentUploads`)
  - `Set<String> _runningTaskIds`
  - `void _tryStartNextTask()`

#### UploadScreen
- UI layout:
  ```
  [Select Files]  [Select Folder]  [Advanced Settings]
  [Video Title field] (solo se single selection? -> per multi: default filenames)
  [Compression Settings - apply to batch]
  [Upload Queue List]
  [Completed List]
  ```
- Per batch multi-file:
  - Compression settings applicate a TUTTI i file selezionati
  - Titolo = nome file (niente campo singolo)
  - Per rename, lasciare la possibilità di editare ogni task (future)

#### Dialogs
- `FolderScanDialog` (progress scanning)
- `InvalidFilesDialog` (lista file scartati)
- `BatchSummaryDialog`

---

## Flusso

### Multi File (File Picker)
1. Utente clicca `Select Files`
2. FilePicker ritorna lista file
3. UI mostra anteprima + conta file validi/invalidi
4. Utente conferma `Start Upload`
5. ViewModel crea `UploadBatch` + `UploadTask` per ogni file
6. Batch messo in coda (stato `pending`)
7. Scheduler avvia fino a `maxConcurrentUploads` task
8. Per ogni task:
   - Extract metadata
   - Compressione (opzionale)
   - Upload (chunked se > soglia)
   - Update progress + persistenza
9. Se task fallisce:
   - Stato `error` + messaggio
   - Batch continua con altri task
10. Al termine:
    - Batch status `completed` se tutti success
    - `partial` se alcuni error
    - Mostra dialog riepilogo

### Folder
1. Utente clicca `Select Folder`
2. FilePicker ritorna path folder
3. ViewModel avvia scanning (async):
   - Cammina nella directory (depth first, max depth)
   - Aggiorna `_folderScanProgress` (UI: "Scanning X files")
   - Filtra file non video
4. Al termine scanning, segue stesso flusso multi file

---

## Edge Cases & Validazione

| Caso                         | Strategia                                             |
|------------------------------|-------------------------------------------------------|
| File già in upload           | Evitare duplicati per path + timestamp (mostrare avviso) |
| Cartella enorme (>500 file)  | Mostrare warning e richiedere conferma                |
| Spazio disco insufficiente   | Controllo prima di compressione (uso `check_disk_space`) |
| FFmpeg mancante (Windows)    | Re-uso dialog esistente (per ogni task al bisogno)   |
| App chiusa a metà            | Persistere stato e riprendere tasks `queued/running` |
| Cambiare compressione a batch già creato | Non permesso; impostazioni applicate al momento della creazione |

---

## Testing Manuale (da creare)
- `docs/GUIDES/dev/MANUAL-TESTING-MULTI-UPLOAD.md`
  - Multi-file success
  - Folder success
  - File invalidi
  - Errori per singolo task
  - Resume dopo riavvio app

---

## File da Modificare/Creare

### Domain
- `lib/domain/entities/upload_batch.dart` (nuovo)
- `lib/domain/entities/upload_task.dart` (estendere con batchId/stage/failureReason)
- `lib/domain/usecases/create_upload_batch_usecase.dart` (nuovo)
- `lib/domain/usecases/start_upload_batch_usecase.dart` (nuovo)
- `lib/domain/usecases/retry_upload_task_usecase.dart` (nuovo)

### Data
- `lib/data/datasources/local/upload_local_datasource.dart` (persistenza batch)
- `lib/data/repositories/upload_repository_impl.dart` (queue + scheduler)
- `lib/data/models/upload_batch_model.dart` (nuovo)

### Presentation
- `lib/features/upload/viewmodels/upload_viewmodel.dart` (nuova logica multi-task)
- `lib/presentation/screens/upload/upload_screen.dart` (UI multi-file)
- `lib/presentation/widgets/upload_queue_list.dart` (nuovo)
- `lib/presentation/widgets/folder_scan_dialog.dart` (nuovo)
- `lib/presentation/widgets/upload_summary_dialog.dart` (riusare/estendere)

### Core
- `lib/core/constants/app_constants.dart`
  - `maxFilesPerBatch`
  - `maxConcurrentUploads`
  - `supportedVideoExtensions`
  - `maxFolderDepth`

---

## Note Implementative
1. **Backward Compatibility:** Se l'utente seleziona un singolo file, l'esperienza rimane identica (campo titolo visibile, rename disponibile).
2. **Batch Settings:** Compression settings selezionate prima della creazione batch si applicano a tutti i file.
3. **Persistenza:** Salvare stato batch + task ogni volta che cambia (per ripristino).
4. **Scheduler:** Usa `Future.microtask` + `await` per evitare blocchi UI; considerare `Isolate` solo in futuro se necessario.
5. **Logging:** Aggiungere log per scanning + queue + errori per semplificare debugging.
6. **Performance:** Limitare scanning e load in UI thread; usare `compute()` o `Isolate` per folder grandi se necessario (futuro).

---

## Dipendenze / Considerazioni Tecniche
- `file_picker` supporta `pickFiles` con `allowMultiple` e `getDirectoryPath`
- Su Android 13+ richiede `READ_MEDIA_VIDEO` (già gestito da plugin)
- Su macOS/Windows, l'accesso a cartelle potrebbe richiedere permessi
- Chunked upload esistente funziona senza modifiche (per file > soglia)

---

## Prossimi Passi
1. Implementare struttura dati (entity, models, persistence)
2. Aggiornare ViewModel e UI
3. Implementare scheduler con concorrenza configurabile
4. Gestire folder scanning con progress
5. Aggiornare documentazione + manual testing

--- 


