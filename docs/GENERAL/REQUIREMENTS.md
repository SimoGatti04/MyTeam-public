# Requisiti Funzionali e Non Funzionali

## Requisiti Funzionali

### Core Features (Prioritarie)

1. **Gestione Video - Upload**
   - Caricamento di video dal dispositivo locale (Android/Windows)
   - Supporto per formati video comuni (MP4, AVI, MOV, MKV, etc.)
   - Progress tracking durante l'upload
   - **Upload multiplo con coda** (server gestisce coda, client invia file)
   - Metadata extraction automatica (durata, risoluzione, codec, etc.)
   - **Server-side**: Gestione coda upload, limitazione upload simultanei

2. **Gestione Video - Download e Streaming**
   - **Download locale**: Scarica video sul dispositivo per riproduzione offline
   - **Streaming**: Riproduzione video direttamente dal server (no download completo)
   - Progress tracking durante il download
   - **Download multiplo con coda** (client gestisce coda, server serve file)
   - Gestione dello storage locale (salvataggio in directory specifiche)
   - **Server-side**: Endpoint download e streaming con supporto Range requests (HTTP 206)
   - Resume download support (ripresa download interrotto)

3. **Streaming Video**
   - Riproduzione video in streaming dal server
   - **Streaming video compresso**: Server serve video compresso (client-side)
   - **Risoluzione**: Video compresso con risoluzione scelta dall'utente (480p, 720p, 1080p, 1440p, 2160p/4K, original)
   - **Framerate**: Video compresso con framerate scelta dall'utente (24fps, 30fps, 60fps, 120fps, original)
   - **Range requests**: Supporto HTTP 206 per streaming efficiente
   - Controlli di riproduzione standard (play, pause, seek, volume)
   - Buffer management ottimizzato per streaming
   - **Server-side**: Serve video compresso ricevuto (NO transcoding)
   - **Future**: Transcoding server-side per permettere download/streaming a qualità diverse (opzionale)

### Features Secondarie (Da Definire)

4. **Gestione Contenuti**
   - Lista dei video disponibili sul server
   - Ricerca e filtraggio
   - Organizzazione in cartelle/playlist
   - Informazioni dettagliate su ogni video (metadata, dimensione, data caricamento)

5. **Gestione Tag e Metadata Avanzati**
   - Sistema di tag per categorizzare video
   - Database per salvare dati relativi ai video
   - **Giocatori**: Tag giocatori partecipanti ai video
   - **Tipo di allenamento/esercizi**: Tag per categorizzare tipo di allenamento o esercizi svolti
   - **Squadra**: Tag per identificare la squadra
   - **Note personali**: Note associate ai video (con timestamp opzionale)
   - **Data di realizzazione**: Data quando il video è stato registrato (estrazione automatica da metadati o impostazione manuale)
   - **Ordinamento e filtraggio**: Ordinamento per data aggiunta, data realizzazione, nome, giocatori, tipo allenamento, squadra
   - **Filtri data**: Filtro per mese, stagione (luglio-giugno), settimana, giorno, intervallo personalizzato
   - Ricerca avanzata per tag, giocatori, note, data

6. **Sincronizzazione**
   - Sync automatica dei metadati
   - Cache intelligente per video più recenti/visti

## Requisiti Non Funzionali

1. **Performance**
   - Upload/Download asincroni e non bloccanti
   - Streaming fluido anche su connessioni limitate
   - Gestione efficiente della memoria durante la riproduzione

2. **Sicurezza**
   - Comunicazione cifrata (HTTPS) - consigliato ma non obbligatorio per uso locale
   - Accesso solo da rete locale/trusted (self-hosted)
   - Nessuna autenticazione necessaria (app privata, utente singolo)

3. **Usabilità**
   - UI intuitiva e responsive
   - Design moderno e coerente
   - Feedback chiaro per tutte le operazioni

4. **Affidabilità**
   - Gestione errori robusta
   - Retry automatico per operazioni fallite
   - Resilienza a interruzioni di rete

5. **Compatibilità**
   - Android: API 21+ (Android 5.0+)
   - Windows: Windows 10+

## Decisioni Prese

1. **Server Hosting**
   - ✅ **Self-hosted**: Maggiore controllo, privacy, uso locale
   - ✅ **Stack tecnologico**: Python + FastAPI

2. **Autenticazione**
   - ✅ **Nessuna autenticazione**: App privata per uso personale, utente singolo
   - Accesso diretto al server, nessun token/sessione

3. **Formati Video e Compressione**
   - Supporto multi-formato: MP4, AVI, MOV, MKV, WebM
   - **Compressione client-side**: Utente comprime video prima upload (480p-4K, 24-120fps)
   - Server riceve e archivia video già compresso
   - **Future**: Transcoding server-side per generare versioni multiple (opzionale)

4. **Storage**
   - Nessuna limitazione di dimensione (configurabile)
   - Gestione storage locale sul server

5. **Backup Automatico**
   - ✅ Backup automatico video su dischi esterni
   - ✅ Rilevamento automatico dischi esterni
   - ✅ Selezione manuale dischi per backup
   - ✅ Scheduling backup (giornaliero, settimanale, custom)
   - ✅ Backup incrementale (solo video nuovi/modificati)
   - ✅ Verifica integrità backup (checksum)
   - ✅ Logging operazioni backup
   - **Server-side**: Gestione completa backup (detection, scheduling, copia)

6. **Database**
   - ✅ Database per metadata video (Phase 1)
   - ✅ Database per tag, persone, azioni, note (Phase 2)
   - Dettagli da definire successivamente

7. **Funzionalità Future (Roadmap)**
   - ✅ Sistema di tag per video
   - ✅ Database per metadata estesi (persone, azioni, note)
   - ✅ Identificazione/tag persone nei video
   - ✅ Tracciamento azioni/eventi nei video
   - ✅ Note personali associate ai video
   - **Transcoding server-side**: Generare versioni multiple per download/streaming a qualità diverse (opzionale)
   - **Chunked upload (resume)**: Upload in chunk con possibilità di riprendere da dove si è interrotto (opzionale, complesso)
   - **Magic number validation**: Verifica formato reale file leggendo primi byte (signature) invece di solo estensione (opzionale, sicurezza)
   - **Priority queue**: Supporto priority queue per upload importanti prima (opzionale)
   - Gestione sottotitoli (da valutare)
   - Playback offline per video scaricati (già previsto)

