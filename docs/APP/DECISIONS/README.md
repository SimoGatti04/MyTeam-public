# Decisioni Tecniche App

## Panoramica

Questa cartella contiene **decisioni tecniche finali specifiche dell'app** Flutter.

---

## File Disponibili

### [client-packages.md](client-packages.md)
**Client-Side Packages**
- Packages necessari
- Uso e implementazione
- Configurazione `pubspec.yaml`

### [upload-flow.md](upload-flow.md)
**Client-Side Upload Flow**
- Connectivity check
- Timeout configurabile
- Upload multipli non bloccanti
- Notifiche a fine processo

### [compression-flow.md](compression-flow.md)
**Compression Flow (Client-Side)**
- Retry compressione
- Storage management file compresso
- Cancellazione compressione/upload

### [video-list.md](video-list.md)
**Video List Implementation**
- Video List Screen con lista scrollabile
- Paginazione automatica (infinite scroll)
- Ricerca in tempo reale
- Sorting configurabile
- Thumbnail lazy loading
- Pull to refresh

### [upload-persistence.md](upload-persistence.md)
**Upload Persistence (Client-Side)**
- Persistenza upload task con SharedPreferences
- Recupero stato all'avvio schermata upload
- Mostra upload in corso/completati anche dopo cambio schermata

### [video-metadata-display.md](video-metadata-display.md)
**Visualizzazione Metadata Video Selezionato (Upload)**
- Estrazione metadata video originale alla selezione
- Visualizzazione risoluzione e FPS originali
- Calcolo e visualizzazione dimensione prevista dopo compressione
- Aggiornamento dinamico quando cambiano impostazioni compressione

### [video-detail-screen.md](video-detail-screen.md)
**Video Detail Screen**
- Schermata dettagli video con metadati completi
- Visualizzazione thumbnail, durata, risoluzione, dimensione
- Informazioni compressione (se disponibili)
- Pulsanti per riproduzione e download (placeholder per future feature)
- Navigazione da VideoListScreen

### [compression-optimization-sports.md](compression-optimization-sports.md)
**Ottimizzazione Compressione Video - Video Calcistici GoPro**
- Hardware acceleration (VideoToolbox/MediaCodec)
- CRF per qualità costante (ottimale per video sportivi)
- Preset bilanciato (veryfast/fast)
- Tune zerolatency per movimento rapido
- Scale algorithm ottimizzato per nitidezza
- Audio copy per velocità
- Ottimizzato per 1080p 30fps e 1440p 60fps

---

## Quando Creare File Qui

✅ **Crea file qui se:**
- Decisione riguarda solo implementazione app
- Decisione riguarda UI/UX/client-side logic
- Decisione riguarda Flutter packages/client architecture
- Decisione riguarda state management/client storage

❌ **NON creare file qui se:**
- Decisione riguarda comunicazione client-server → `GENERAL/DECISIONS/`
- Decisione riguarda solo server → `SERVER/DECISIONS/`

---

Per decisioni generali:
- **Vedere**: `GENERAL/DECISIONS/`
