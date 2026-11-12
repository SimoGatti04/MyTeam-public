# Requisiti App Flutter - MoSCoW

## Priorità MoSCoW

### Must Have

#### M1. Upload Video
- Selezione video dal dispositivo (file_picker)
- Compressione video client-side (480p-4K, 24-120fps)
- Selezione risoluzione e framerate
- Preview dimensione finale post-compressione
- Upload video compresso al server
- Progress tracking durante upload

#### M2. Download Video
- Download video dal server
- Progress tracking durante download
- Salvataggio in storage locale
- Gestione download queue (client-side)
- Resume download support

#### M3. Streaming Video
- Riproduzione video in streaming dal server
- Player con controlli (play, pause, seek, volume)
- Buffer management ottimizzato
- Range requests support automatico

#### M4. Lista Video
- Visualizzazione lista video disponibili
- Thumbnail per ogni video
- Informazioni video (durata, dimensione, data aggiunta, data realizzazione)
- Ricerca e filtraggio
- Ordinamento (data aggiunta, data realizzazione, nome, giocatori, tipo allenamento, squadra)
- Filtri avanzati (data: mese, stagione, settimana, giorno, intervallo; giocatori, tipo allenamento, squadra)

#### M5. Compressione Client-Side
- Estrazione metadata video originale
- Selezione risoluzione (480p-4K, original)
- Selezione framerate (24-120fps, original)
- Stima dimensione finale
- Compressione con FFmpeg
- Progress tracking compressione

---

### Should Have

#### S1. Offline Support
- Riproduzione video scaricati offline
- Cache metadata video
- Gestione storage locale

#### S2. Notifiche
- Notifiche upload completato
- Notifiche download completato
- Progress notifications

---

### Could Have

#### C1. Organizzazione Video Avanzata
- Playlist locali
- Favoriti video
- Tag personalizzati

#### C2. UI/UX Avanzata
- Animazioni
- Theme support
- Customization

---

### Won't Have (Future)

#### W1. Azioni/Eventi nei Video
- Tracciamento eventi specifici nel video (es: goal, falli)
- Timeline eventi durante riproduzione

#### W2. Autenticazione
- Login/logout
- Gestione sessioni

---

## Requisiti Non Funzionali

### Performance
- UI responsive e non bloccante
- Background tasks per upload/download
- Efficiente gestione memoria

### Usabilità
- UI intuitiva
- Design moderno
- Feedback chiaro per tutte le operazioni

### Compatibilità
- Android: API 21+ (Android 5.0+)
- Windows: Windows 10+

---

## Stack Tecnologico

### Framework
- **Flutter** - Framework multipiattaforma

### Packages Principali
- **dio** - HTTP client
- **video_player** - Video playback
- **ffmpeg_kit_flutter_new** - Video compression e metadata extraction (fork mantenuto di ffmpeg_kit_flutter discontinuato)
- **file_picker** - File selection
- **path_provider** - Storage paths
- **shared_preferences** - Settings persistence

### Architettura
- **Clean Architecture** - Presentation/Domain/Data layers
- **Repository Pattern** - Astrazione accesso dati
- **State Management** - Da decidere (Provider/Riverpod/Bloc)

---

**Nota:** App non ancora implementata. Questo documento sarà aggiornato durante lo sviluppo.

Per requisiti generali, vedere `GENERAL/REQUIREMENTS.md`.

