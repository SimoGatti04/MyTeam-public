# Testing Manuale - Rename Video Feature

**Data:** 2025-01-15  
**Feature:** Rename Video (prima upload + dopo upload)

---

## Prerequisiti

1. **Server attivo** sulla porta 8000
2. **App Flutter** in esecuzione (Android/macOS/Windows)
3. **Video di test** disponibili sul dispositivo

---

## Test 1: Rename Prima Upload

### Obiettivo
Verificare che l'utente possa modificare il titolo del video prima di caricarlo.

### Passi

1. **Avvia l'app** e naviga alla schermata **Upload**
2. **Seleziona un video** usando il pulsante "Choose Video File"
3. **Verifica che:**
   - Il campo "Video Title" appaia dopo la selezione del file
   - Il campo sia pre-compilato con il nome del file (senza estensione)
   - Esempio: se il file è `my_video.mp4`, il campo dovrebbe contenere `my_video`

4. **Modifica il titolo:**
   - Cambia il testo nel campo "Video Title"
   - Esempio: cambia `my_video` in `Test Video 2025`

5. **Configura compressione** (opzionale):
   - Seleziona risoluzione e framerate desiderati

6. **Clicca "Upload Video"**

7. **Verifica che:**
   - L'upload proceda normalmente
   - Il video venga caricato con il titolo modificato (non il nome file originale)
   - Nella lista video, il video appaia con il titolo modificato

### Test Case 1.1: Titolo Vuoto (Fallback a Filename)

1. Seleziona un video
2. **Svuota completamente** il campo "Video Title"
3. Clicca "Upload Video"
4. **Verifica che:**
   - L'upload proceda normalmente
   - Il video venga caricato con il nome del file originale come titolo

### Test Case 1.2: Titolo Molto Lungo

1. Seleziona un video
2. **Inserisci un titolo molto lungo** (>255 caratteri)
3. **Verifica che:**
   - Il campo mostri un contatore (max 255 caratteri)
   - Il campo limiti l'input a 255 caratteri
   - Non sia possibile inserire più di 255 caratteri

### Test Case 1.3: Rimozione File Selezionato

1. Seleziona un video
2. Verifica che il campo "Video Title" sia visibile e pre-compilato
3. **Clicca "Remove"** per rimuovere il file selezionato
4. **Verifica che:**
   - Il campo "Video Title" scompaia
   - Il campo sia vuoto quando selezioni un nuovo file

### Test Case 1.4: Selezione File Multipla (Verifica Comportamento)

1. Seleziona un video (`video1.mp4`)
2. Verifica che il titolo sia pre-compilato con `video1`
3. **Rimuovi il file** e seleziona un altro video (`video2.mp4`)
4. **Verifica che:**
   - Il campo titolo sia aggiornato con `video2`
   - Il campo non mantenga il titolo del file precedente

---

## Test 2: Rename Dopo Upload

### Obiettivo
Verificare che l'utente possa modificare il titolo dei video già caricati.

### Passi

1. **Avvia l'app** e naviga alla schermata **Videos**
2. **Seleziona un video** dalla lista (clicca su un video)
3. **Verifica che:**
   - La schermata Video Detail si apra
   - Il titolo del video sia visibile in alto
   - **Icona edit** (matita) sia visibile accanto al titolo

4. **Clicca l'icona edit** accanto al titolo
5. **Verifica che:**
   - Un dialog "Edit Video Title" appaia
   - Il campo TextField sia pre-compilato con il titolo corrente
   - Il campo abbia focus automatico (autofocus)
   - I pulsanti "Cancel" e "Save" siano visibili

6. **Modifica il titolo:**
   - Cambia il testo nel campo
   - Esempio: cambia `Test Video` in `Test Video - Renamed`

7. **Clicca "Save"**
8. **Verifica che:**
   - Un SnackBar "Updating title..." appaia brevemente
   - Il dialog si chiuda
   - Un SnackBar verde "Title updated successfully" appaia
   - Il titolo nella schermata Video Detail sia aggiornato immediatamente
   - Il nuovo titolo sia visibile (senza bisogno di ricaricare)

9. **Torna alla lista video** (back button)
10. **Verifica che:**
    - Il video nella lista mostri il nuovo titolo
    - Il titolo sia aggiornato anche nella lista

### Test Case 2.1: Annullamento Modifica

1. Apri Video Detail Screen
2. Clicca icona edit
3. **Modifica il titolo** nel dialog
4. **Clicca "Cancel"**
5. **Verifica che:**
   - Il dialog si chiuda
   - Il titolo nella schermata rimanga invariato
   - Nessun SnackBar di successo/errore appaia

### Test Case 2.2: Salvataggio Senza Modifiche

1. Apri Video Detail Screen
2. Clicca icona edit
3. **NON modificare** il titolo (lascia invariato)
4. **Clicca "Save"**
5. **Verifica che:**
   - Il pulsante "Save" sia disabilitato o non faccia nulla
   - Oppure che il dialog si chiuda senza chiamate API (ottimizzazione)

### Test Case 2.3: Titolo Vuoto (Validazione)

1. Apri Video Detail Screen
2. Clicca icona edit
3. **Svuota completamente** il campo titolo
4. **Clicca "Save"**
5. **Verifica che:**
   - Il pulsante "Save" sia disabilitato o non permetta il salvataggio
   - Un messaggio di errore appaia (se implementato)
   - Il titolo non venga aggiornato

### Test Case 2.4: Titolo Troppo Lungo (Validazione)

1. Apri Video Detail Screen
2. Clicca icona edit
3. **Inserisci un titolo >255 caratteri**
4. **Verifica che:**
   - Il campo mostri un contatore (max 255 caratteri)
   - Il campo limiti l'input a 255 caratteri
   - Non sia possibile inserire più di 255 caratteri

### Test Case 2.5: Errore Server (Network Error)

1. Apri Video Detail Screen
2. **Disconnetti internet** (o ferma il server)
3. Clicca icona edit
4. Modifica il titolo
5. Clicca "Save"
6. **Verifica che:**
   - Un SnackBar rosso con messaggio di errore appaia
   - Il messaggio sia user-friendly (es: "Failed to update title: Connection error")
   - Il titolo nella schermata rimanga invariato

### Test Case 2.6: Video Non Trovato (404)

1. Apri Video Detail Screen di un video esistente
2. **Elimina il video dal server** (manualmente o tramite altra interfaccia)
3. Clicca icona edit
4. Modifica il titolo
5. Clicca "Save"
6. **Verifica che:**
   - Un SnackBar rosso con messaggio di errore appaia
   - Il messaggio indichi che il video non è stato trovato
   - Il titolo nella schermata rimanga invariato

---

## Test 3: Integrazione e Edge Cases

### Test Case 3.1: Caratteri Speciali nel Titolo

1. **Rename prima upload:**
   - Seleziona un video
   - Inserisci un titolo con caratteri speciali: `Test & Video (2025) - [Special]`
   - Upload il video
   - **Verifica che** il titolo sia salvato correttamente

2. **Rename dopo upload:**
   - Apri Video Detail Screen
   - Modifica il titolo con caratteri speciali
   - Salva
   - **Verifica che** il titolo sia aggiornato correttamente

### Test Case 3.2: Titolo con Spazi Multipli

1. Seleziona un video
2. Inserisci un titolo con spazi multipli: `Test    Video    2025`
3. Upload il video
4. **Verifica che:**
   - Il titolo sia salvato (spazi multipli possono essere mantenuti o normalizzati, a seconda dell'implementazione)
   - Il titolo sia visualizzato correttamente

### Test Case 3.3: Titolo Solo Spazi

1. Seleziona un video
2. Inserisci solo spazi nel campo titolo: `     `
3. **Verifica che:**
   - Il sistema tratti questo come titolo vuoto
   - Usi il filename come fallback durante upload

### Test Case 3.4: Aggiornamento Titolo Durante Upload

1. Seleziona un video
2. Modifica il titolo
3. **Inizia l'upload**
4. **Durante l'upload**, prova a modificare il titolo (se il campo è ancora visibile)
5. **Verifica che:**
   - Il campo sia disabilitato durante upload (se implementato)
   - Oppure che le modifiche non influenzino l'upload in corso

### Test Case 3.5: Refresh Lista Dopo Rename

1. Apri Video Detail Screen
2. Modifica il titolo
3. Salva
4. Torna alla lista video
5. **Ricarica la lista** (pull to refresh o navigazione)
6. **Verifica che:**
   - Il nuovo titolo sia visibile nella lista
   - Il titolo sia persistente (non torni al vecchio valore)

---

## Test 4: Performance e UX

### Test Case 4.1: Feedback Visivo

1. **Rename dopo upload:**
   - Apri Video Detail Screen
   - Clicca icona edit
   - Modifica titolo
   - Clicca "Save"
   - **Verifica che:**
     - Un indicatore di loading appaia (SnackBar "Updating title...")
     - Il feedback sia immediato
     - Il titolo si aggiorni senza delay visibile

### Test Case 4.2: Navigazione Durante Update

1. Apri Video Detail Screen
2. Clicca icona edit
3. Modifica titolo
4. Clicca "Save"
5. **Immediatamente dopo**, clicca back button (prima che l'update finisca)
6. **Verifica che:**
   - La navigazione funzioni normalmente
   - L'update continui in background
   - Il titolo sia aggiornato quando torni alla schermata

### Test Case 4.3: Multiple Rename Rapid

1. Apri Video Detail Screen
2. Clicca icona edit
3. Modifica titolo e salva
4. **Immediatamente dopo**, clicca di nuovo icona edit
5. Modifica titolo di nuovo e salva
6. **Verifica che:**
   - Entrambi gli update vengano processati correttamente
   - Non ci siano race conditions
   - Il titolo finale sia quello dell'ultimo update

---

## Checklist Finale

### Rename Prima Upload
- [ ] Campo titolo appare dopo selezione file
- [ ] Campo è pre-compilato con nome file (senza estensione)
- [ ] Titolo modificato viene usato durante upload
- [ ] Titolo vuoto usa filename come fallback
- [ ] Validazione max 255 caratteri funziona
- [ ] Campo viene pulito quando si rimuove il file

### Rename Dopo Upload
- [ ] Icona edit è visibile accanto al titolo
- [ ] Dialog edit appare correttamente
- [ ] Campo è pre-compilato con titolo corrente
- [ ] Modifica titolo funziona
- [ ] Feedback visivo (loading, success, error) funziona
- [ ] Titolo si aggiorna immediatamente nella UI
- [ ] Titolo si aggiorna anche nella lista video
- [ ] Validazione (vuoto, troppo lungo) funziona
- [ ] Gestione errori (network, 404) funziona

### Integrazione
- [ ] Caratteri speciali funzionano
- [ ] Spazi multipli gestiti correttamente
- [ ] Refresh lista mostra titolo aggiornato
- [ ] Performance accettabile (nessun lag visibile)

---

## Note

- **Tutti i test devono essere eseguiti su tutte le piattaforme supportate** (Android, macOS, Windows)
- **In caso di errori**, verificare i log del server e dell'app
- **Per test di errore network**, usare strumenti come Charles Proxy o disabilitare temporaneamente la connessione

---

## Risultati Attesi

### Comportamento Normale
- ✅ Rename prima upload: titolo modificato viene usato per l'upload
- ✅ Rename dopo upload: titolo viene aggiornato nel database e nella UI
- ✅ Feedback visivo chiaro per tutte le operazioni
- ✅ Validazione previene input invalidi

### Comportamento in Caso di Errore
- ✅ Messaggi di errore user-friendly
- ✅ UI non si blocca in caso di errori
- ✅ Stato precedente viene mantenuto in caso di errore

