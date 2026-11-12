# Come Leggere i Log dell'App Windows

## Panoramica

Su Windows, i log dell'app Flutter possono essere letti in diversi modi a seconda di come l'app viene eseguita.

## Metodi per Leggere i Log

### 1. Esecuzione da Terminale (Consigliato per Debug)

Se esegui l'app da terminale (PowerShell o Command Prompt), i log vengono mostrati direttamente nella console.

#### Esecuzione da Terminale:

```powershell
# Naviga alla cartella del progetto
cd C:\path\to\MyTeam

# Esegui l'app in modalità debug
flutter run -d windows
```

**Vantaggi:**
- ✅ Vedi tutti i log in tempo reale
- ✅ `debugPrint()` viene mostrato nella console
- ✅ Errori e stack trace visibili immediatamente
- ✅ Facile da usare per debugging

**Output:**
```
I/flutter: 🎬 [Compression Windows] Progress: 25.5% (frame 255/1000)
I/flutter: 🎬 [Compression Windows] Progress: 50.0% (frame 500/1000)
```

### 2. Esecuzione dell'Eseguibile (.exe)

Se esegui l'app direttamente dal file `.exe` (release build), i log **non vengono salvati automaticamente su file** (file logging è attualmente disattivato).

**Nota:** Il file logging può essere riattivato modificando `_enabled = true` in `lib/core/utils/file_logger.dart`.

### 3. Event Viewer (Windows)

Windows Event Viewer può mostrare alcuni log dell'app, ma non tutti i log Flutter.

**Come aprire Event Viewer:**
1. Premi `Win + R`
2. Digita `eventvwr.msc` e premi Enter
3. Naviga a **Windows Logs > Application**
4. Cerca eventi con nome "myteam" o "Flutter"

**Limitazioni:**
- ❌ Non mostra `debugPrint()` personalizzati
- ❌ Mostra solo errori critici del sistema
- ❌ Non mostra log di compressione/upload

### 4. Visual Studio Output Window

Se compili l'app con Visual Studio, puoi vedere i log nella finestra "Output".

**Come:**
1. Apri il progetto in Visual Studio
2. Compila ed esegui l'app (F5)
3. Vai a **View > Output** (o `Ctrl+Alt+O`)
4. Seleziona "Debug" nel dropdown

### 5. Debug Console in VS Code

Se usi VS Code con Flutter, i log vengono mostrati nella Debug Console.

**Come:**
1. Apri il progetto in VS Code
2. Vai a **Run > Start Debugging** (F5)
3. I log appaiono nella **Debug Console**

## Log Specifici per Compressione

I log di compressione su Windows includono:

### Formato Log Compressione:

```
🎬 [Compression Windows] Esecuzione FFmpeg: ffmpeg -i "input.mp4" ...
🎬 [Compression Windows] Progress: 25.5% (frame 255/1000)
🎬 [Compression Windows] Progress: 50.0% (frame 500/1000)
✅ [Compression Windows] Lettura stderr completata (totale linee: 1234, ultimo frame: 1000)
```

### Cosa Cercare nei Log:

1. **Progress Frame:**
   - `frame= 123` - Numero frame processato
   - `time=00:00:04.12` - Tempo processato
   - `Progress: X% (frame Y/Z)` - Progress basato su frame

2. **Errori:**
   - `⚠️ [Compression Windows] Errore lettura stderr` - Problema lettura output FFmpeg
   - `❌ [Compression Windows] FFmpeg compression failed` - Errore compressione
   - `Error creating a MFX session` - Errore hardware encoder

3. **Debug:**
   - `📊 [Compression Windows] Linee processate: X` - Numero linee stderr processate
   - `⚠️ [Compression Windows] Linea senza frame/time` - Linee che non contengono progress info

## Troubleshooting Progress Bloccato a 0%

Se il progress è bloccato a 0%, controlla i log per:

### 1. FFmpeg Non Emette Output Frame

**Sintomo:**
```
⚠️ [Compression Windows] Linea senza frame/time: ...
```

**Causa:** FFmpeg non sta emettendo informazioni di progress nel formato atteso.

**Soluzione:**
- Verifica che FFmpeg usi `-loglevel info` (non `error`)
- Verifica che il comando FFmpeg sia corretto
- Controlla che FFmpeg sia la versione corretta

### 2. Encoding Stderr Non Leggibile

**Sintomo:**
```
⚠️ [Compression Windows] Errore lettura stderr: ...
```

**Causa:** Problema di encoding (UTF-8 vs SystemEncoding).

**Soluzione:**
- Il codice ora usa `Utf8Decoder` per gestire meglio l'encoding
- Verifica che FFmpeg emetta output in formato standard

### 3. totalFrames Non Disponibile

**Sintomo:**
```
🎬 [Compression Windows] Progress incrementale: X% (frame Y)
```

**Causa:** `totalFrames` non è stato calcolato correttamente.

**Soluzione:**
- Verifica che i metadata del video siano stati estratti correttamente
- Controlla che `VideoMetadataService.extractMetadata()` funzioni

## Comandi Utili

### Verifica Log in Tempo Reale:

```powershell
# Se l'app è in esecuzione da terminale, i log appaiono automaticamente
flutter run -d windows

# Per vedere solo errori
flutter run -d windows 2>&1 | Select-String "ERROR|❌"
```

### Salva Log su File:

```powershell
# Esegui app e salva log
flutter run -d windows 2>&1 | Tee-Object -FilePath "app_logs.txt"
```

### Cerca Log Specifici:

```powershell
# Cerca log di compressione
Get-Content app_logs.txt | Select-String "Compression Windows"

# Cerca errori
Get-Content app_logs.txt | Select-String "ERROR|❌|⚠️"
```

## Note Importanti

1. **Release Build:** I log `debugPrint()` vengono rimossi in release build per default. Per vedere i log in release, devi abilitare logging esplicito.

2. **Performance:** Logging eccessivo può rallentare l'app. I log vengono mostrati ogni 50-100 frame per bilanciare visibilità e performance.

3. **Encoding:** Su Windows, FFmpeg può emettere output in encoding diverso. Il codice ora usa `Utf8Decoder` per gestire meglio questo.

4. **Stderr vs Stdout:** FFmpeg emette progress su `stderr`, non `stdout`. Il codice legge correttamente da `stderr`.

## Esempio Completo

```powershell
# 1. Apri PowerShell
# 2. Naviga al progetto
cd %USERPROFILE%\Documents\Workspace\MyTeam

# 3. Esegui app in debug
flutter run -d windows

# 4. I log appaiono in tempo reale:
# I/flutter: 🎬 [Compression Windows] Esecuzione FFmpeg: ffmpeg -i "%USERPROFILE%"
# I/flutter: 🎬 [Compression Windows] Progress: 10.0% (frame 100/1000)
# I/flutter: 🎬 [Compression Windows] Progress: 20.0% (frame 200/1000)
# ...
```

## Riferimenti

- [Flutter Debugging](https://docs.flutter.dev/testing/debugging)
- [FFmpeg Logging](https://ffmpeg.org/ffmpeg.html#Generic-options)
- [Windows Event Viewer](https://docs.microsoft.com/en-us/windows/win32/eventlog/event-viewer)

