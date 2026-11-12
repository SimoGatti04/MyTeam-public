# TODO - Feature da Implementare

**Data creazione:** 2024-12-19  
**Stato progetto:** Pulizia completata, codice stabile

---

## Feature Prioritarie

### 1. Video Detail Screen ✅ COMPLETATO
- **Descrizione:** Implementare schermata dettagli video con metadati completi e opzioni riproduzione/download
- **Priorità:** Alta
- **Stato:** ✅ Completato e testato
- **Note:**
  - ✅ App: Creare `VideoDetailScreen` con dettagli completi
  - ✅ Mostrare metadati (durata, risoluzione, dimensione, data upload)
  - ✅ Mostrare thumbnail
  - ✅ Pulsanti per riproduzione/download (placeholder per future feature)
  - ✅ Navigazione da `VideoListScreen`
  - ✅ Repository e endpoint server già implementati
  - **File implementati:**
    - `lib/domain/usecases/get_video_by_id_usecase.dart` (nuovo)
    - `lib/features/video/viewmodels/video_detail_viewmodel.dart` (nuovo)
    - `lib/presentation/screens/video/video_detail_screen.dart` (nuovo)
    - `lib/presentation/screens/video/video_list_screen.dart` (modificato - navigazione)
  - **Documentazione:** `docs/APP/DECISIONS/video-detail-screen.md`
  - **Test:** `docs/GUIDES/dev/MANUAL-TESTING-VIDEO-DETAIL.md`

### 1.1. Visualizzazione Info Video Selezionato (Upload) ✅ COMPLETATO
- **Descrizione:** Mostrare all'utente qualità e FPS del file originale selezionato, e dimensione prevista dopo compressione
- **Priorità:** Alta
- **Stato:** ✅ Completato e testato
- **Note:**
  - ✅ App: Estrarre metadata video selezionato usando `VideoMetadataService`
  - ✅ Mostrare qualità originale (risoluzione: width x height) del file selezionato
  - ✅ Mostrare FPS originali del file selezionato
  - ✅ Calcolare e mostrare dimensione prevista del file risultante dopo compressione (basata su risoluzione e framerate scelti nelle impostazioni)
  - ✅ Mostrare info video originale e preview dimensione finale nella schermata upload
  - ✅ Aggiornare preview dimensione quando l'utente cambia risoluzione/framerate nelle impostazioni
  - **File implementati:**
    - `lib/presentation/screens/widgets/video_info_widget.dart` (nuovo)
    - `lib/presentation/screens/upload/upload_screen.dart` (modificato)
    - `lib/features/upload/services/video_compression_service.dart` (migliorato `estimateCompressedSize`)
  - **Documentazione:** `docs/APP/DECISIONS/video-metadata-display.md`
  - **Test:** `docs/GUIDES/dev/MANUAL-TESTING-VIDEO-METADATA.md`

### 2. Streaming Video ✅ COMPLETATO
- **Descrizione:** Implementare streaming video per riproduzione diretta senza download completo
- **Priorità:** Alta
- **Stato:** ✅ Completato e testato
- **Note:**
  - ✅ Server: Endpoint `/api/videos/{video_id}/stream` con supporto Range requests (HTTP 206)
  - ✅ App: `VideoPlayerScreen` con player video e controlli (play, pause, seek, progress)
  - ✅ Integrazione: Player integrato in `VideoDetailScreen` (sostituito placeholder Play button)
  - ✅ Supporto: HTTP Range requests per streaming efficiente
  - **File implementati:**
    - `server/app/api/routes/videos.py` (modificato - aggiunto `stream_video()`)
    - `lib/presentation/screens/video/video_player_screen.dart` (nuovo)
    - `lib/presentation/screens/video/video_detail_screen.dart` (modificato - integrazione player)
  - **Documentazione:** `docs/APP/DECISIONS/video-streaming.md`
  - **Future:** Considerare qualità multiple (adaptive streaming HLS/DASH)

### 2.1. Ottimizzazione Compressione Video
- **Descrizione:** Ottimizzare la compressione video per renderla più veloce
- **Priorità:** Alta
- **Note:**
  - **Hardware Acceleration:** Usare encoding hardware se disponibile
    - macOS: `-c:v h264_videotoolbox` (VideoToolbox)
    - Windows: `-c:v h264_qsv` (Intel QSV) / `-c:v h264_nvenc` (NVIDIA) / `-c:v h264_amf` (AMD)
    - Android: `-c:v h264_mediacodec` (disabilitato per stabilità, usa software encoding)
    - Vantaggio: 5-10x più veloce rispetto a software encoding
  - **Threading:** Aggiungere `-threads 0` per usare tutti i core CPU
  - **CRF:** Usare `-crf 23` o `-crf 28` invece di bitrate fisso (più veloce e migliore qualità/dimensione)
  - **Audio:** `-c:a copy` se audio non cambia, oppure downsampling se non critico
  - **Tune:** Aggiungere `-tune fastdecode` o `-tune zerolatency` per velocità
  - **VSync:** `-vsync 0` o `-vsync passthrough` per evitare frame duplicati
  - **Preset:** Mantenere `ultrafast` o considerare `veryfast` per migliore qualità/dimensione

### 3. Download Video
- **Descrizione:** Permettere download di video dal server all'app
- **Priorità:** Alta
- **Note:**
  - Server: Endpoint per download video
  - App: Gestione download con progress tracking
  - Salvataggio locale dei video scaricati

### 4. Upload File Multipli
- **Descrizione:** Permettere upload di più file contemporaneamente
- **Priorità:** Media
- **Note:**
  - App: Selezione multipla file
  - Gestione coda upload multipli
  - Progress tracking per ogni file

### 4.1. Gestione Errori più Robusta
- **Descrizione:** Migliorare gestione errori con messaggi chiari e retry automatico
- **Priorità:** Media
- **Note:**
  - Messaggi di errore chiari e user-friendly
  - Retry automatico dove possibile
  - Feedback visivo per stati di errore
  - Gestione errori di rete, upload, compressione
  - Toast/notifiche per errori critici

### 5. Modifica Dettagli Video ✅ COMPLETATO (Rename Video)
- **Descrizione:** Permettere modifica di metadati video (nome, data, tags, notes)
- **Priorità:** Media
- **Stato:** ✅ Completato (Rename Video implementato)
- **Note:**
  - ✅ Server: Endpoint PUT `/api/videos/{id}` per aggiornamento titolo
  - ✅ App: Rename prima upload (campo editabile) e dopo upload (dialog edit)
  - ✅ Validazione e salvataggio modifiche
  - ✅ Feedback UI completo (loading, success, error)
  - **File implementati:**
    - `server/app/api/routes/videos.py` (endpoint PUT)
    - `server/app/services/video_service.py` (metodo update_video_title)
    - `lib/domain/usecases/update_video_title_usecase.dart` (nuovo)
    - `lib/presentation/screens/upload/upload_screen.dart` (campo titolo editabile)
    - `lib/presentation/screens/video/video_detail_screen.dart` (UI edit titolo)
  - **Documentazione:** `docs/APP/DECISIONS/video-rename.md`
  - **Test:** `docs/GUIDES/dev/MANUAL-TESTING-VIDEO-RENAME.md`

### 6. Upload Multipli
- **Descrizione:** Migliorare gestione upload multipli con coda avanzata
- **Priorità:** Media
- **Note:**
  - Coda upload con priorità
  - Pausa/riprendi upload
  - Gestione errori per singoli file

### 7. Migliorare UI
- **Descrizione:** Miglioramenti generali all'interfaccia utente
- **Priorità:** Bassa
- **Note:**
  - Design più moderno e intuitivo
  - Migliorare UX per upload/compressione
  - Aggiungere animazioni e transizioni
  - Migliorare feedback visivo per operazioni

---

## Note Implementazione

- Tutte le feature devono seguire l'architettura Clean Architecture esistente
- Mantenere coerenza con il codice attuale
- Aggiungere test per ogni nuova feature
- Aggiornare documentazione per ogni implementazione

---

## Stato Attuale

- ✅ Upload singolo video con compressione
- ✅ Lista video con paginazione
- ✅ Progress tracking per upload e compressione
- ✅ Persistenza upload task
- ✅ Cancellazione upload/compressione
- ✅ Thumbnail generation
- ✅ Visualizzazione metadata video selezionato (risoluzione, FPS, dimensione prevista)
- ✅ Video Detail Screen con metadati completi e navigazione
- ✅ Streaming video con supporto Range requests (HTTP 206)
- ✅ Video Player con controlli (play, pause, seek, progress)
- ✅ Rename Video (prima upload + dopo upload)

