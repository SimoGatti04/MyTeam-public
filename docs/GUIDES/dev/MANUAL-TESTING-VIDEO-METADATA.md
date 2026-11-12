# Test Manuale - Visualizzazione Metadata Video Selezionato

## Panoramica

Questa guida descrive come testare manualmente la nuova feature di visualizzazione metadata video selezionato nella schermata upload.

## Feature Testata

- Estrazione metadata video originale alla selezione
- Visualizzazione risoluzione originale (width x height)
- Visualizzazione FPS originali
- Calcolo e visualizzazione dimensione prevista dopo compressione
- Aggiornamento dinamico quando cambiano le impostazioni di compressione

---

## Prerequisiti

1. **App Flutter compilata e in esecuzione**
2. **File video di test** con metadata noti (risoluzione, FPS)
3. **Server in esecuzione** (opzionale, per test upload completo)

---

## Test Case

### Test 1: Selezione Video e Estrazione Metadata

**Obiettivo:** Verificare che i metadata vengano estratti correttamente alla selezione del video.

**Passi:**
1. Avvia l'app Flutter
2. Naviga alla schermata "Upload Video"
3. Clicca su "Choose Video File"
4. Seleziona un file video

**Risultato Atteso:**
- Il video viene selezionato
- Dopo qualche secondo, appare un card "Video Info" con:
  - Risoluzione originale (es. "1920x1080")
  - FPS originali (es. "30.0 fps")
  - Dimensione prevista (es. "~45.2 MB") o indicatore di caricamento

**Verifica:**
- ✅ Risoluzione mostrata correttamente
- ✅ FPS mostrato correttamente
- ✅ Dimensione prevista calcolata (o loading indicator visibile)

---

### Test 2: Calcolo Dimensione Prevista

**Obiettivo:** Verificare che la dimensione prevista venga calcolata correttamente.

**Passi:**
1. Seleziona un video (come Test 1)
2. Attendi che la dimensione prevista venga calcolata
3. Verifica che la dimensione sia ragionevole rispetto al video originale

**Risultato Atteso:**
- La dimensione prevista viene mostrata con prefisso "~" (es. "~45.2 MB")
- La dimensione è minore o uguale alla dimensione originale (se compressione attiva)
- La dimensione è uguale alla dimensione originale (se "Original" è selezionato)

**Verifica:**
- ✅ Dimensione prevista mostrata
- ✅ Formato corretto (KB, MB, GB)
- ✅ Valore ragionevole

---

### Test 3: Aggiornamento Dinamico - Cambio Risoluzione

**Obiettivo:** Verificare che la dimensione prevista si aggiorni quando cambia la risoluzione.

**Passi:**
1. Seleziona un video (come Test 1)
2. Attendi che la dimensione prevista venga calcolata
3. Nota la dimensione prevista iniziale
4. Cambia la risoluzione nelle "Compression Settings" (es. da 1080p a 720p)
5. Osserva la dimensione prevista

**Risultato Atteso:**
- La dimensione prevista si aggiorna automaticamente
- La nuova dimensione è minore della precedente (se risoluzione ridotta)
- L'aggiornamento avviene senza dover ricaricare la pagina

**Verifica:**
- ✅ Dimensione prevista aggiornata
- ✅ Valore corretto (minore per risoluzione più bassa)
- ✅ Aggiornamento immediato

---

### Test 4: Aggiornamento Dinamico - Cambio Framerate

**Obiettivo:** Verificare che la dimensione prevista si aggiorni quando cambia il framerate.

**Passi:**
1. Seleziona un video (come Test 1)
2. Attendi che la dimensione prevista venga calcolata
3. Nota la dimensione prevista iniziale
4. Cambia il framerate nelle "Compression Settings" (es. da 60 fps a 30 fps)
5. Osserva la dimensione prevista

**Risultato Atteso:**
- La dimensione prevista si aggiorna automaticamente
- La nuova dimensione è minore della precedente (se framerate ridotto)
- L'aggiornamento avviene senza dover ricaricare la pagina

**Verifica:**
- ✅ Dimensione prevista aggiornata
- ✅ Valore corretto (minore per framerate più basso)
- ✅ Aggiornamento immediato

---

### Test 5: Impostazione "Original"

**Obiettivo:** Verificare che con "Original" la dimensione prevista sia uguale all'originale.

**Passi:**
1. Seleziona un video (come Test 1)
2. Nelle "Compression Settings", seleziona "Original"
3. Osserva la dimensione prevista

**Risultato Atteso:**
- La dimensione prevista è uguale alla dimensione originale del file
- Non c'è riduzione di dimensione

**Verifica:**
- ✅ Dimensione prevista = dimensione originale
- ✅ Nessuna compressione applicata

---

### Test 6: Rimozione Video

**Obiettivo:** Verificare che i metadata vengano rimossi correttamente quando si rimuove il video.

**Passi:**
1. Seleziona un video (come Test 1)
2. Verifica che i metadata siano visibili
3. Clicca su "Remove" per rimuovere il video
4. Verifica che i metadata non siano più visibili

**Risultato Atteso:**
- Il video viene rimosso
- Il card "Video Info" scompare
- Lo stato viene resettato correttamente

**Verifica:**
- ✅ Video rimosso
- ✅ Metadata non più visibili
- ✅ Stato resettato

---

### Test 7: Gestione Errori - Estrazione Metadata Fallita

**Obiettivo:** Verificare che l'app gestisca correttamente errori durante l'estrazione metadata.

**Passi:**
1. Prova a selezionare un file video corrotto o non valido (se possibile)
2. Oppure simula un errore durante l'estrazione

**Risultato Atteso:**
- Il video viene comunque selezionato
- I metadata non vengono mostrati (card "Video Info" non appare)
- L'app non crasha
- L'utente può comunque procedere con l'upload (se il file è valido)

**Verifica:**
- ✅ Nessun crash
- ✅ Gestione errore graceful
- ✅ App ancora utilizzabile

---

### Test 8: Video con Metadata Mancanti

**Obiettivo:** Verificare che l'app gestisca video con metadata parziali.

**Passi:**
1. Seleziona un video che potrebbe non avere tutti i metadata (es. FPS mancante)
2. Verifica cosa viene mostrato

**Risultato Atteso:**
- I metadata disponibili vengono mostrati
- I metadata mancanti non causano errori
- La dimensione prevista viene comunque calcolata (con fallback)

**Verifica:**
- ✅ Solo metadata disponibili mostrati
- ✅ Nessun errore per metadata mancanti
- ✅ Dimensione prevista calcolata comunque

---

## Test di Integrazione

### Test 9: Upload Completo con Metadata

**Obiettivo:** Verificare che l'upload funzioni correttamente con i metadata visualizzati.

**Passi:**
1. Seleziona un video
2. Verifica che i metadata siano corretti
3. Configura le impostazioni di compressione
4. Verifica la dimensione prevista
5. Clicca su "Upload Video"
6. Attendi che l'upload completi

**Risultato Atteso:**
- L'upload procede normalmente
- I metadata originali vengono inviati al server (se implementato)
- Il video viene caricato correttamente

**Verifica:**
- ✅ Upload completato con successo
- ✅ Metadata corretti sul server (se verificabile)

---

## Checklist Completa

- [ ] Test 1: Selezione video e estrazione metadata
- [ ] Test 2: Calcolo dimensione prevista
- [ ] Test 3: Aggiornamento dinamico - cambio risoluzione
- [ ] Test 4: Aggiornamento dinamico - cambio framerate
- [ ] Test 5: Impostazione "Original"
- [ ] Test 6: Rimozione video
- [ ] Test 7: Gestione errori estrazione metadata
- [ ] Test 8: Video con metadata mancanti
- [ ] Test 9: Upload completo con metadata

---

## Note

- **Performance**: L'estrazione metadata può richiedere alcuni secondi per video grandi
- **Calcolo Dimensione**: Il calcolo della dimensione prevista è una stima basata su area e framerate ratio
- **Aggiornamento**: L'aggiornamento della dimensione prevista avviene in background e non blocca l'UI
- **Fallback**: Se i metadata non sono disponibili, viene usato un fallback conservativo

---

## Troubleshooting

### Metadata Non Vengono Estratti

1. Verifica che FFprobe sia disponibile nell'app
2. Verifica i log per errori durante l'estrazione
3. Verifica che il file video sia valido

### Dimensione Prevista Non Si Aggiorna

1. Verifica che le impostazioni di compressione siano cambiate correttamente
2. Verifica i log per errori durante il calcolo
3. Prova a rimuovere e riselezionare il video

### Card "Video Info" Non Appare

1. Verifica che i metadata siano stati estratti correttamente
2. Verifica che il video sia selezionato
3. Controlla i log per errori

