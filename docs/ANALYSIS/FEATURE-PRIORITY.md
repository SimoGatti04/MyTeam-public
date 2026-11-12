# Analisi Priorità Feature - Prossimi Passi

**Data:** 2025-01-15  
**Stato:** Analisi completata

---

## Feature Proposte

### 1. Rename Video
- **Prima upload:** Permettere modifica del titolo prima di caricare
- **Dopo upload:** Permettere modifica del titolo dei video già caricati

### 2. Upload Multipli
- **Descrizione:** Caricare più video contemporaneamente (almeno da Windows)
- **Priorità utente:** Alta

---

## Analisi Dettagliata

### 1. Rename Video

#### Stato Attuale
- ✅ Campo `title` esiste nel modello Video (server e client)
- ✅ Durante upload, il titolo viene passato al server
- ❌ **Prima upload:** Il titolo viene generato automaticamente dal filename, non c'è campo editabile
- ❌ **Dopo upload:** Non esiste endpoint server per aggiornare il titolo
- ❌ **UI:** Non c'è modo di modificare il titolo nella VideoDetailScreen

#### Complessità Implementativa
- **Prima upload:** 🟢 **Bassa**
  - Aggiungere `TextFormField` nella schermata upload
  - Pre-compilare con filename (come default)
  - Passare il titolo modificato all'upload
  - **Tempo stimato:** 2-3 ore

- **Dopo upload:** 🟡 **Media**
  - Server: Creare endpoint `PUT /api/videos/{id}` per aggiornare titolo
  - Server: Aggiungere metodo `update_video_title()` in `VideoService`
  - Client: Creare use case `UpdateVideoTitleUseCase`
  - Client: Aggiungere repository method per update
  - Client: Aggiungere UI in `VideoDetailScreen` (icona edit + dialog)
  - **Tempo stimato:** 4-6 ore

#### Valore per l'Utente
- 🟢 **Alto** - Organizzazione video essenziale
- Utile per identificare video facilmente
- Migliora UX significativamente

#### Dipendenze
- Nessuna dipendenza da altre feature
- Base solida già presente (modello Video con campo title)

---

### 2. Upload Multipli

#### Stato Attuale
- ✅ Server: `UploadQueueService` già implementato (gestisce coda server-side)
- ✅ Client: `UploadViewModel` ha lista `_uploadTasks` (struttura pronta)
- ✅ Client: UI mostra già lista di task (completati, in corso, errori)
- ❌ **Selezione multipla:** `file_picker` supporta `allowMultiple: true`, ma non usato
- ❌ **Gestione coda client:** Upload sequenziale, non parallelo
- ❌ **UI:** Non ottimizzata per mostrare più upload simultanei

#### Complessità Implementativa
- 🟡 **Media-Alta**
  - Modificare `_handleFileSelection()` per supportare selezione multipla
  - Gestire coda upload client-side (sequenziale o parallelo?)
  - Modificare `UploadViewModel` per gestire task multipli simultanei
  - Aggiornare UI per mostrare progress di ogni file
  - Gestione errori per singoli file (non bloccare altri upload)
  - **Tempo stimato:** 1-2 giorni

#### Valore per l'Utente
- 🟢 **Alto** - Efficienza operativa
- Utile per caricare batch di video
- Riduce tempo totale di upload

#### Dipendenze
- Nessuna dipendenza critica
- Struttura già pronta (queue service, task management)

---

## Confronto e Raccomandazione

### Confronto Diretto

| Criterio | Rename Video | Upload Multipli |
|---------|-------------|-----------------|
| **Complessità** | 🟢 Bassa-Media | 🟡 Media-Alta |
| **Valore Utente** | 🟢 Alto | 🟢 Alto |
| **Tempo Implementazione** | 6-9 ore | 1-2 giorni |
| **Dipendenze** | Nessuna | Nessuna |
| **Rischio** | 🟢 Basso | 🟡 Medio |

### Raccomandazione: **Iniziare con Rename Video**

#### Motivi:
1. **Più veloce da implementare** (6-9 ore vs 1-2 giorni)
2. **Rischio più basso** (feature più semplice)
3. **Valore immediato** per l'utente
4. **Prepara il terreno** per altre feature di modifica video
5. **Nessuna dipendenza** da altre feature

#### Ordine Suggerito:
1. **Rename Video (Prima Upload)** - 2-3 ore
   - Aggiungere campo editabile nella schermata upload
   - Pre-compilare con filename
   - Passare titolo modificato all'upload

2. **Rename Video (Dopo Upload)** - 4-6 ore
   - Endpoint server `PUT /api/videos/{id}`
   - Use case e repository client
   - UI in VideoDetailScreen

3. **Upload Multipli** - 1-2 giorni
   - Selezione multipla file
   - Coda upload client-side
   - UI per progress multipli

---

## Altre Priorità da Considerare

### Download Video (TODO Priorità Alta)
- **Stato:** Non implementato
- **Valore:** Alto (feature core)
- **Complessità:** Media
- **Raccomandazione:** Implementare dopo Rename Video, prima di Upload Multipli

### Gestione Errori più Robusta (TODO Priorità Media)
- **Stato:** Parzialmente implementato
- **Valore:** Medio-Alto
- **Complessità:** Media
- **Raccomandazione:** Migliorare gradualmente durante sviluppo altre feature

---

## Piano di Implementazione Suggerito

### Fase 1: Rename Video (1-2 giorni)
1. ✅ Rename prima upload (2-3 ore)
2. ✅ Rename dopo upload (4-6 ore)
3. ✅ Test e documentazione (2-3 ore)

### Fase 2: Download Video (2-3 giorni)
1. Endpoint server download
2. Use case e repository client
3. UI per download con progress
4. Gestione storage locale

### Fase 3: Upload Multipli (1-2 giorni)
1. Selezione multipla file
2. Coda upload client-side
3. UI per progress multipli
4. Gestione errori per singoli file

---

## Conclusione

**Raccomandazione finale:** Iniziare con **Rename Video** perché:
- ✅ Più veloce da implementare
- ✅ Rischio più basso
- ✅ Valore immediato per l'utente
- ✅ Prepara il terreno per altre feature

**Ordine suggerito:**
1. Rename Video (prima + dopo upload) - **1-2 giorni**
2. Download Video - **2-3 giorni**
3. Upload Multipli - **1-2 giorni**

