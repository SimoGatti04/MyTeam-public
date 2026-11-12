# Test Manuale - Video Detail Screen

## Panoramica

Questa guida descrive come testare manualmente la schermata Video Detail Screen.

---

## Prerequisiti

1. **App Flutter compilata e in esecuzione**
2. **Server in esecuzione** con almeno un video caricato
3. **Connessione** tra app e server funzionante

---

## Test Case

### Test 1: Navigazione da Video List

**Obiettivo:** Verificare che la navigazione funzioni correttamente.

**Passi:**
1. Avvia l'app Flutter
2. Naviga alla schermata "Video" (lista video)
3. Verifica che ci siano video nella lista
4. Tocca un video nella lista

**Risultato Atteso:**
- Navigazione alla schermata "Video Details"
- AppBar mostra "Video Details"
- Nessun crash o errore

**Verifica:**
- ✅ Navigazione funziona
- ✅ Screen si apre correttamente
- ✅ Nessun errore

---

### Test 2: Caricamento Dettagli Video

**Obiettivo:** Verificare che i dettagli video vengano caricati correttamente.

**Passi:**
1. Naviga a Video Detail Screen (come Test 1)
2. Attendi il caricamento

**Risultato Atteso:**
- Mostra `CircularProgressIndicator` durante il caricamento
- Dopo il caricamento, mostra i dettagli del video
- Titolo del video visibile
- Thumbnail caricato (o placeholder se non disponibile)

**Verifica:**
- ✅ Loading indicator visibile durante caricamento
- ✅ Dettagli video mostrati dopo caricamento
- ✅ Titolo corretto
- ✅ Thumbnail caricato o placeholder mostrato

---

### Test 3: Visualizzazione Thumbnail

**Obiettivo:** Verificare che il thumbnail venga visualizzato correttamente.

**Passi:**
1. Apri Video Detail Screen per un video con thumbnail
2. Osserva il thumbnail

**Risultato Atteso:**
- Thumbnail caricato e visualizzato
- Dimensioni corrette (larghezza piena, altezza ~200px)
- Loading indicator durante caricamento
- Fallback a icona se thumbnail non disponibile o errore

**Verifica:**
- ✅ Thumbnail visualizzato correttamente
- ✅ Dimensioni corrette
- ✅ Loading durante caricamento
- ✅ Fallback funziona se thumbnail mancante

---

### Test 4: Visualizzazione Metadati

**Obiettivo:** Verificare che tutti i metadati vengano visualizzati correttamente.

**Passi:**
1. Apri Video Detail Screen
2. Scorri per vedere tutti i metadati

**Risultato Atteso:**
- **Titolo**: Nome del video (font grande e bold)
- **Descrizione**: Se disponibile, mostrata sotto il titolo
- **Status Badge**: Badge colorato (verde=ready, arancione=processing, rosso=error)
- **Video Information Card** con:
  - Duration (formattata: "1h 23m 45s" o "23m 45s" o "45s")
  - Resolution (es. "1920x1080")
  - File Size (formattata: "5.0 GB" o "45.2 MB")
  - Format (es. "MP4")
  - Uploaded (data e ora formattata)
  - Codec (se disponibile)
  - Bitrate (se disponibile, formattato: "5.0 Mbps")
  - Framerate (se disponibile, es. "30.0 fps")

**Verifica:**
- ✅ Tutti i metadati disponibili mostrati
- ✅ Formattazione corretta (durata, dimensione, bitrate, date)
- ✅ Metadati mancanti non causano errori
- ✅ Layout corretto e leggibile

---

### Test 5: Informazioni Compressione

**Obiettivo:** Verificare che le informazioni di compressione vengano mostrate se disponibili.

**Passi:**
1. Apri Video Detail Screen per un video compresso
2. Verifica sezione "Compression Information"

**Risultato Atteso:**
- Sezione "Compression Information" visibile (card blu chiaro)
- Mostra:
  - Original Resolution (se disponibile)
  - Original Framerate (se disponibile)
  - Compressed Framerate (se disponibile)
  - Original File Size (se disponibile)
  - Compression Ratio (se disponibile, es. "75.0%")

**Verifica:**
- ✅ Sezione compressione visibile se dati disponibili
- ✅ Tutte le informazioni compressione mostrate correttamente
- ✅ Sezione non visibile se dati non disponibili

---

### Test 6: Status Badge

**Obiettivo:** Verificare che lo status badge sia corretto.

**Passi:**
1. Apri Video Detail Screen per video con status diversi
2. Verifica il badge di status

**Risultato Atteso:**
- **Ready**: Badge verde con testo "Ready"
- **Processing**: Badge arancione con testo "Processing"
- **Error**: Badge rosso con testo "Error"
- **Deleted**: Badge grigio con testo "Deleted"

**Verifica:**
- ✅ Badge colorato correttamente
- ✅ Testo corretto
- ✅ Stile visibile e leggibile

---

### Test 7: Pulsanti Azione

**Obiettivo:** Verificare che i pulsanti Play e Download funzionino.

**Passi:**
1. Apri Video Detail Screen
2. Verifica pulsanti Play e Download

**Risultato Atteso:**
- **Play**: Pulsante elevato con icona play e testo "Play"
- **Download**: Pulsante outlined con icona download e testo "Download"
- Entrambi abilitati se status = ready
- Entrambi disabilitati se status != ready
- Al tap, mostrano SnackBar con messaggio (placeholder)

**Verifica:**
- ✅ Pulsanti visibili e correttamente posizionati
- ✅ Abilitati/disabilitati in base allo status
- ✅ SnackBar mostrato al tap (placeholder)

---

### Test 8: Gestione Errori - Video Non Trovato

**Obiettivo:** Verificare che gli errori vengano gestiti correttamente.

**Passi:**
1. Prova ad aprire Video Detail Screen con un ID video non valido
2. Oppure ferma il server e prova a caricare un video

**Risultato Atteso:**
- Mostra messaggio di errore
- Icona errore rossa
- Pulsante "Retry" disponibile
- Nessun crash

**Verifica:**
- ✅ Errore gestito gracefully
- ✅ Messaggio errore chiaro
- ✅ Pulsante retry funziona
- ✅ Nessun crash

---

### Test 9: Refresh Video Details

**Obiettivo:** Verificare che il refresh funzioni.

**Passi:**
1. Apri Video Detail Screen
2. Se c'è un errore, clicca "Retry"
3. Oppure modifica il video sul server e fai refresh

**Risultato Atteso:**
- Pulsante "Retry" ricarica i dettagli
- Loading indicator durante refresh
- Dettagli aggiornati dopo refresh

**Verifica:**
- ✅ Refresh funziona
- ✅ Loading durante refresh
- ✅ Dettagli aggiornati

---

### Test 10: Scroll e Layout

**Obiettivo:** Verificare che lo scroll e il layout funzionino correttamente.

**Passi:**
1. Apri Video Detail Screen
2. Scorri su e giù
3. Verifica layout su schermi di dimensioni diverse

**Risultato Atteso:**
- Scroll fluido
- Tutti gli elementi visibili
- Layout responsive
- Nessun overflow

**Verifica:**
- ✅ Scroll funziona correttamente
- ✅ Tutti gli elementi accessibili
- ✅ Layout corretto su diverse dimensioni schermo

---

## Checklist Completa

- [ ] Test 1: Navigazione da Video List
- [ ] Test 2: Caricamento Dettagli Video
- [ ] Test 3: Visualizzazione Thumbnail
- [ ] Test 4: Visualizzazione Metadati
- [ ] Test 5: Informazioni Compressione
- [ ] Test 6: Status Badge
- [ ] Test 7: Pulsanti Azione
- [ ] Test 8: Gestione Errori
- [ ] Test 9: Refresh Video Details
- [ ] Test 10: Scroll e Layout

---

## Note

- **Thumbnail URL**: Costruito usando `ApiConstants.videoThumbnail(videoId)`
- **Metadati Opzionali**: Tutti i metadati sono opzionali e gestiti correttamente
- **Formattazione**: Durata, dimensione file, bitrate e date sono formattati correttamente
- **Performance**: Caricamento thumbnail lazy con loading indicator
- **Error Handling**: Gestione errori completa con retry

---

## Troubleshooting

### Thumbnail Non Carica

1. Verifica che il server sia in esecuzione
2. Verifica URL thumbnail nel log
3. Verifica che il video abbia un thumbnail sul server
4. Controlla permessi CORS se necessario

### Metadati Mancanti

1. Verifica che il video sul server abbia i metadati estratti
2. Controlla la risposta API nel log
3. Verifica che `VideoResponse.toEntity()` mappi correttamente i campi

### Errore di Navigazione

1. Verifica che `VideoDetailScreen` sia importato correttamente
2. Verifica che `videoId` sia passato correttamente
3. Controlla i log per errori di navigazione

