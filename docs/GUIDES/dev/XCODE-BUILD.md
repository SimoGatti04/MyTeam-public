# Build e Esecuzione macOS con Xcode

**Nota:** Questa guida è solo per macOS. iOS non è supportato in questo progetto.

## Panoramica

Per macOS, l'app viene buildata ed eseguita direttamente tramite Xcode invece di usare Flutter CLI. Questo evita problemi di code signing e configurazione.

## ⚡ Fix Rapido Problemi Comuni

**Se vedi errori in Xcode dopo modifiche al codice o aggiornamenti dipendenze**, esegui questo script:

```bash
./scripts/fix_xcode_issues.sh
```

Lo script risolve automaticamente:
- ✅ File `.xcfilelist` mancanti (FlutterInputs/FlutterOutputs)
- ✅ File CocoaPods `.xcfilelist` mancanti
- ✅ PrivacyInfo.xcprivacy per volume_controller
- ✅ Rigenera file ephemeral Flutter
- ✅ Aggiorna dipendenze CocoaPods
- ✅ Verifica configurazione Flutter (FLUTTER_ROOT)

**Quando eseguirlo:**
- Dopo `flutter pub get` o aggiornamenti `pubspec.yaml`
- Dopo modifiche al codice che causano errori in Xcode
- Quando vedi errori "Unable to load contents of file list"
- Quando vedi errori "PrivacyInfo.xcprivacy"
- Quando vedi errori "Command PhaseScriptExecution failed"

## Prerequisiti

1. **Xcode** installato (versione 14.0 o superiore)
2. **CocoaPods** installato: `brew install cocoapods`
3. **Flutter** installato (per generare i file necessari)
4. **Server** attivo sulla porta 8000

## Setup Iniziale

### 1. Genera File Flutter

**IMPORTANTE:** Anche se macOS desktop è disabilitato in Flutter CLI, i file generati sono necessari per Xcode.

```bash
cd $MYTEAM_REPO_ROOT

# Temporaneamente riabilita macOS desktop per generare i file
flutter config --enable-macos-desktop

# Genera i file necessari (genera anche FlutterInputs.xcfilelist e FlutterOutputs.xcfilelist)
flutter pub get

# Genera i file .xcfilelist necessari per Xcode (esegue un build parziale)
# Questo può fallire con code signing, ma genera comunque i file necessari
flutter build macos --debug 2>&1 || echo "Build fallito (normale se code signing non configurato), ma file generati"

# Disabilita nuovamente macOS desktop (opzionale)
flutter config --no-enable-macos-desktop
```

**Nota:** I file generati (inclusi `.xcfilelist`) rimangono anche dopo aver disabilitato macOS desktop, quindi puoi eseguire questo passaggio una sola volta.

### 2. Installa Dipendenze CocoaPods

```bash
cd macos
pod install
cd ..
```

## Build e Esecuzione

### Metodo 1: Build e Run tramite Xcode (Consigliato)

#### 1. Apri Xcode

```bash
open macos/Runner.xcworkspace
```

**IMPORTANTE:** Usa sempre `.xcworkspace`, non `.xcodeproj`!

#### 2. Configura Code Signing

1. Seleziona il progetto "Runner" nel navigatore
2. Seleziona il target "Runner"
3. Vai alla scheda **"Signing & Capabilities"**
4. Seleziona **"Automatically manage signing"**
5. Seleziona il tuo **Team** (se hai un Apple ID)
   - Oppure imposta **"Sign to Run Locally"** per debug senza team

#### 3. Configura Entitlements

Assicurati che i file `.entitlements` contengano:
- `com.apple.security.files.user-selected.read-write`
- `com.apple.security.files.downloads.read-write`
- `com.apple.security.network.client`

I file sono già configurati in:
- `macos/Runner/Debug.entitlements`
- `macos/Runner/DebugProfile.entitlements`
- `macos/Runner/Release.entitlements`

#### 4. Seleziona Schema e Dispositivo

1. In alto nella barra degli strumenti di Xcode:
   - Seleziona lo schema: **"Runner"**
   - Seleziona il dispositivo: **"My Mac"** (o il tuo Mac specifico)

#### 5. Build e Run

- Premi **⌘R** (Cmd+R) per buildare ed eseguire
- Oppure clicca il bottone **"Play"** in alto a sinistra

### Metodo 2: Build tramite Script (Alternativa)

Se preferisci usare lo script automatizzato:

```bash
cd $MYTEAM_REPO_ROOT
./scripts/build_macos.sh
```

Poi apri l'app generata:
```bash
open build/macos/Build/Products/Debug/Runner.app
```

**Nota:** Lo script gestisce automaticamente:
- Rimozione extended attributes
- Code signing temporaneo
- Fix architettura (arm64)

## Debug: App macOS non si apre

Se l'app macOS non si apre o crasha all'avvio, segui questi passaggi:

### 1. Attiva Debug Mode prima del build

1. **Modifica `lib/core/services/settings_service.dart`** (temporaneamente) per forzare debug mode:
   ```dart
   static bool getDebugMode() {
     return true; // Forza debug mode per troubleshooting
   }
   ```

2. **Oppure** modifica `lib/main.dart` per inizializzare debug mode:
   ```dart
   Future<void> _initializeServices() async {
     await SettingsService.initialize();
     await SettingsService.setDebugMode(true); // Forza debug mode
     DebugLogger.info('Services initialized');
   }
   ```

3. **Rebuild in Xcode** (⌘R)

4. **Controlla i log** nell'overlay di debug quando l'app si avvia

### 2. Verifica log in Xcode Console

1. In Xcode, apri **View > Debug Area > Activate Console** (⌘⇧Y)
2. Esegui l'app (⌘R)
3. Controlla i messaggi di errore nella console
4. Cerca errori come:
   - `dyld: Library not loaded`
   - `FFmpeg` errors
   - `Exception` o `Error`

### 3. Verifica log su file

I log vengono salvati anche su file (su macOS in release mode):

```bash
# I log sono salvati in:
# ~/Documents/MyTeam/myteam_log_YYYY-MM-DD_HH-MM-SS.txt

# Lista tutti i log:
ls -la ~/Documents/MyTeam/myteam_log_*.txt

# Visualizza l'ultimo log:
ls -t ~/Documents/MyTeam/myteam_log_*.txt | head -1 | xargs cat

# Oppure in tempo reale:
ls -t ~/Documents/MyTeam/myteam_log_*.txt | head -1 | xargs tail -f
```

**Nota:** I log su file sono abilitati solo in **release mode** (non in debug mode). In debug mode, usa l'overlay di debug nell'app o la console di Xcode.

### 4. Test senza compressione video

Se sospetti che il problema sia con FFmpeg/compressione:

1. **Commenta temporaneamente** l'uso di `VideoCompressionService` in `lib/features/upload/viewmodels/upload_viewmodel.dart`
2. **Rebuild** e testa se l'app si avvia
3. Se si avvia, il problema è con FFmpeg

### 5. Verifica dipendenze FFmpeg

```bash
# Verifica che FFmpeg sia disponibile
ffmpeg -version

# Se non installato, installa:
brew install ffmpeg
```

## Troubleshooting

### Crash SIGABRT all'avvio

**Problema:** L'app crasha all'avvio con `Thread 1: signal SIGABRT`

**Possibili cause e soluzioni:**

1. **Errore: Library not loaded (zlib, libiconv, ecc.) - RISOLTO:**
   
   Se vedi errori come:
   ```
   dyld: Library not loaded: /opt/homebrew/opt/zlib/lib/libz.1.dylib
   dyld: Library not loaded: /opt/homebrew/opt/libiconv/lib/libiconv.2.dylib
   Referenced from: .../libswresample.framework/...
   ```
   
   **Causa:** FFmpeg ha path hardcoded che cercano le librerie Homebrew in percorsi specifici.
   
   **Soluzione:**
   - I file `Flutter-Debug.xcconfig` e `Flutter-Release.xcconfig` sono già configurati con i path di zlib e libiconv
   - Installa le dipendenze mancanti:
     ```bash
     brew install zlib libiconv
     ```
   - Se vedi altri errori simili, installa anche:
     ```bash
     brew install bzip2 xz lzma
     ```
   - Pulisci e ricompila in Xcode:
     1. **Product > Clean Build Folder** (⌘ShiftK)
     2. **Product > Build** (⌘B)
     3. **Product > Run** (⌘R)
   
   **Nota:** Se il problema persiste dopo aver installato le librerie, potrebbe essere necessario aggiornare i path hardcoded nel framework FFmpeg usando `install_name_tool` (vedi soluzione avanzata sotto).

2. **FFmpeg su macOS:**
   - `ffmpeg_kit_flutter_new` potrebbe non essere completamente supportato su macOS
   - Verifica i log di crash in Xcode (Console) per vedere se l'errore è legato a FFmpeg
   - Se il problema è FFmpeg, considera di disabilitare la compressione video su macOS o usare FFmpeg di sistema

3. **Verifica log di crash:**
   - In Xcode, apri **View > Debug Area > Activate Console**
   - Esegui l'app e controlla i messaggi di errore prima del crash
   - Cerca errori come "dyld: Library not loaded" o riferimenti a FFmpeg

3. **Permessi mancanti:**
   - Verifica che i file `.entitlements` contengano tutti i permessi necessari
   - Aggiungi se necessario:
     ```xml
     <key>com.apple.security.files.user-selected.read-write</key>
     <true/>
     <key>com.apple.security.files.downloads.read-write</key>
     <true/>
     ```

4. **Plugin non compatibili:**
   - Alcuni plugin potrebbero non essere compatibili con macOS
   - Verifica i log per vedere quale plugin causa il crash

5. **Test senza FFmpeg:**
   - Commenta temporaneamente l'uso di FFmpeg nel codice
   - Se l'app si avvia, il problema è con FFmpeg
   - Considera di usare FFmpeg di sistema invece del plugin

6. **Soluzione avanzata: Fix path hardcoded in FFmpeg (se necessario):**
   
   Se i Library Search Paths non risolvono il problema, puoi modificare i path hardcoded nel framework FFmpeg:
   
   ```bash
   # Trova il framework FFmpeg
   FRAMEWORK_PATH="macos/Flutter/ephemeral/.symlinks/plugins/ffmpeg_kit_flutter_new/macos/Classes/Frameworks"
   
   # Modifica i path per zlib
   install_name_tool -change /opt/homebrew/opt/zlib/lib/libz.1.dylib @rpath/libz.1.dylib "$FRAMEWORK_PATH/libswresample.framework/libswresample"
   
   # Modifica i path per libiconv
   install_name_tool -change /opt/homebrew/opt/libiconv/lib/libiconv.2.dylib @rpath/libiconv.2.dylib "$FRAMEWORK_PATH/libswresample.framework/libswresample"
   ```
   
   **Nota:** Questa soluzione richiede di eseguire lo script dopo ogni `flutter pub get` o aggiornamento del plugin.

### Error: Unable to load contents of file list (.xcfilelist)

**Problema:** Xcode mostra errori:
```
Unable to load contents of file list: '.../FlutterInputs.xcfilelist'
Unable to load contents of file list: '.../FlutterOutputs.xcfilelist'
Unable to read contents of XCFileList '/Target Support Files/Pods-Runner/...'
```

**Soluzione Rapida (Consigliata):**

Esegui lo script automatico che risolve tutti i problemi comuni:

```bash
cd $MYTEAM_REPO_ROOT
./scripts/fix_xcode_issues.sh
```

**Soluzione Manuale:**

1. **Rigenera i file con Flutter e CocoaPods:**
   ```bash
   cd $MYTEAM_REPO_ROOT
   flutter config --enable-macos-desktop
   flutter pub get
   flutter build macos --debug 2>&1 | grep -v "CodeSign" || true
   cd macos
   pod install
   cd ..
   flutter config --no-enable-macos-desktop
   ```
   
   Questo dovrebbe generare tutti i file `.xcfilelist` necessari.

2. **Se CocoaPods fallisce con errore "shellScript Array":**
   
   Questo è un bug noto di CocoaPods. Il file `project.pbxproj` ha `shellScript` definiti come array invece di stringhe. La soluzione è già applicata nel progetto, ma se vedi ancora l'errore:
   
   - I file `shellScript` nel `project.pbxproj` sono stati convertiti da array a stringhe
   - Se il problema persiste, esegui `pod install` di nuovo

3. **Verifica i file generati:**
   ```bash
   # File Flutter
   ls -la macos/Flutter/ephemeral/*.xcfilelist
   
   # File CocoaPods
   ls -la macos/Pods/Target\ Support\ Files/Pods-Runner/*.xcfilelist
   ```

**Nota:** I file `.xcfilelist` sono file di testo che elencano i file di input e output per il build system di Xcode. Vengono generati automaticamente da Flutter e CocoaPods.

### Error: PrivacyInfo.xcprivacy (volume_controller)

**Problema:** Xcode mostra errore:
```
no rule to process file '$HOME/.pub-cache/hosted/pub.dev/volume_controller-3.4.0/macos/volume_controller/Sources/volume_controller/PrivacyInfo.xcprivacy' of type 'text.xml' for architecture 'arm64'
```

**Causa:** Il plugin `volume_controller` include un file `PrivacyInfo.xcprivacy` richiesto da Apple, ma Xcode non sa come processarlo automaticamente.

**Soluzione:**

1. **Automatica (consigliata):**
   ```bash
   ./scripts/fix_xcode_issues.sh
   ```
   Lo script copia automaticamente il file nella directory corretta.

2. **Manuale:**
   
   a. **Copia il file:**
      ```bash
      mkdir -p macos/Runner/PrivacyInfo
      cp ~/.pub-cache/hosted/pub.dev/volume_controller-3.4.0/macos/volume_controller/Sources/volume_controller/PrivacyInfo.xcprivacy macos/Runner/PrivacyInfo/
      ```
   
   b. **Aggiungi al progetto in Xcode:**
      - Apri `macos/Runner.xcworkspace` in Xcode
      - Clicca destro su `Runner` nel navigator
      - Seleziona "Add Files to Runner..."
      - Seleziona `macos/Runner/PrivacyInfo/PrivacyInfo.xcprivacy`
      - Assicurati che "Copy items if needed" sia **deselezionato** (il file è già nella posizione corretta)
      - Assicurati che "Add to targets: Runner" sia **selezionato**
      - Clicca "Add"
   
   c. **Verifica Target Membership:**
      - Seleziona `PrivacyInfo.xcprivacy` in Xcode
      - Nella tab "File Inspector" (⌘⌥1), verifica che "Target Membership" > "Runner" sia selezionato
      - Verifica che il file sia nella sezione "Copy Bundle Resources" in Build Phases

**Nota:** Questo file è richiesto da Apple per le app macOS/iOS che accedono a dati sensibili. Il file descrive le pratiche di privacy dell'app.

### Warning: Run script build phase

**Problema:** Xcode mostra warning:
```
Run script build phase 'Run Script' will be run during every build because it does not specify any outputs.
```

**Causa:** Uno script di build non ha output paths specificati, quindi Xcode lo esegue sempre per sicurezza.

**Soluzione:**

Questo è solo un **warning**, non un errore. L'app funziona comunque. Se vuoi eliminare il warning:

1. In Xcode, vai su **Build Phases** del target "Runner"
2. Trova la fase "Run Script" che mostra il warning (di solito è "embed" o "Flutter Assemble")
3. Espandi la fase
4. **Deseleziona** "Based on dependency analysis"

**Nota:** Questo warning è normale per script che non generano file ma eseguono operazioni (come incorporare framework).

### Warning: Update to recommended settings

**Problema:** Xcode mostra:
```
Update to recommended settings
```

**Causa:** Xcode suggerisce di aggiornare alcune impostazioni del progetto alla versione più recente.

**Soluzione:**

Questo è solo un **suggerimento**, non un errore. Puoi:

1. **Ignorarlo** - L'app funziona comunque
2. **Applicare le modifiche** - Clicca "Perform Changes" se vuoi aggiornare le impostazioni

**Nota:** Le modifiche suggerite sono generalmente sicure, ma potrebbero cambiare alcune configurazioni del progetto. Se non sei sicuro, puoi ignorare questo warning.

### Error: Command PhaseScriptExecution failed with a nonzero exit code

**Problema:** Xcode mostra:
```
Command PhaseScriptExecution failed with a nonzero exit code
```

**Causa:** Uno degli script di build (Flutter Assemble, CocoaPods, ecc.) è fallito. Questo è un errore generico che può avere diverse cause.

**Soluzione Rapida:**

Esegui lo script di fix che risolve la maggior parte dei problemi:

```bash
./scripts/fix_xcode_issues.sh
```

**Soluzione Manuale (per causa specifica):**

#### 1. Flutter Assemble Script fallito

**Errore tipico:**
```
/bin/sh: /path/to/flutter/packages/flutter_tools/bin/macos_assemble.sh: No such file or directory
```

**Cause possibili:**
- `FLUTTER_ROOT` non è impostato correttamente
- Flutter non è installato o non è nel PATH
- File ephemeral mancanti

**Soluzione:**
```bash
# Verifica che Flutter sia nel PATH
which flutter

# Se non trovato, aggiungi Flutter al PATH o usa FVM
export PATH="$PATH:/path/to/flutter/bin"

# Rigenera file ephemeral
flutter config --enable-macos-desktop
flutter pub get
flutter build macos --debug 2>&1 | grep -v "CodeSign" || true
flutter config --no-enable-macos-desktop

# Oppure usa FVM se configurato
fvm flutter pub get
```

#### 2. CocoaPods Check Manifest fallito

**Errore tipico:**
```
error: The sandbox is not in sync with the Podfile.lock. Run 'pod install' or update your CocoaPods installation.
```

**Soluzione:**
```bash
cd macos
pod install
cd ..
```

#### 3. CocoaPods Embed Frameworks fallito

**Errore tipico:**
```
Unable to load contents of file list: '.../Pods-Runner-frameworks-*-input-files.xcfilelist'
```

**Soluzione:**
```bash
cd macos
pod install --repo-update
cd ..
```

#### 4. File ephemeral mancanti

**Errore tipico:**
```
Unable to load contents of file list: '.../FlutterInputs.xcfilelist'
```

**Soluzione:**
```bash
flutter config --enable-macos-desktop
flutter pub get
flutter build macos --debug 2>&1 | grep -v "CodeSign" || true
flutter config --no-enable-macos-desktop
```

#### 5. Verifica quale script fallisce

Per identificare quale script fallisce:

1. **In Xcode:**
   - Vai su **View > Navigators > Show Report Navigator** (⌘9)
   - Seleziona l'ultimo build fallito
   - Espandi "Run Script" o "PhaseScriptExecution"
   - Cerca il messaggio di errore specifico

2. **Oppure controlla i log:**
   - In Xcode, apri **View > Debug Area > Activate Console** (⌘⇧Y)
   - Cerca messaggi di errore durante il build

#### 6. Soluzione generale

Se non riesci a identificare lo script specifico:

```bash
# 1. Pulisci tutto
cd $MYTEAM_REPO_ROOT
rm -rf build/macos/
cd macos
rm -rf Pods/ Podfile.lock
cd ..

# 2. Rigenera tutto
flutter clean
flutter pub get
cd macos
pod install
cd ..

# 3. Verifica Flutter
flutter doctor

# 4. Rigenera file ephemeral
flutter config --enable-macos-desktop
flutter build macos --debug 2>&1 | grep -v "CodeSign" || true
flutter config --no-enable-macos-desktop

# 5. Riapri Xcode
open macos/Runner.xcworkspace
```

#### 7. Se usi FVM

Se stai usando FVM per gestire Flutter:

```bash
# Assicurati che FVM sia configurato
fvm flutter --version

# Usa FVM per tutti i comandi Flutter
fvm flutter clean
fvm flutter pub get
fvm flutter build macos --debug 2>&1 | grep -v "CodeSign" || true
```

**Nota:** Se il problema persiste, controlla i log dettagliati in Xcode Report Navigator per vedere l'errore specifico dello script.

### Error: Entitlements modificati durante il build

**Errore:**
```
Entitlements file "Debug.entitlements" was modified during the build, which is not supported.
```

**Soluzione:**
✅ **Già risolto:** `CODE_SIGN_ALLOW_ENTITLEMENTS_MODIFICATION = YES` è già configurato in tutte le configurazioni (Debug, Release, Profile).

Se vedi ancora questo errore:
1. Verifica che `macos/Runner.xcodeproj/project.pbxproj` contenga:
   ```
   CODE_SIGN_ALLOW_ENTITLEMENTS_MODIFICATION = YES;
   ```
   in tutte le configurazioni (Debug, Release, Profile)

2. Se non presente, aggiungilo manualmente in Xcode:
   - Vai su "Build Settings" del target "Runner"
   - Cerca "Allow Entitlements Modification"
   - Imposta su "Yes"

### Error: Entitlements non trovati

**Errore:**
```
PlatformException(ENTITLEMENT_NOT_FOUND, Either the Read-Only or Read-Write entitlement is required for this action., null, null)
```

**Soluzione:**
1. Verifica che `macos/Runner/Debug.entitlements` contenga:
   ```xml
   <key>com.apple.security.files.user-selected.read-write</key>
   <true/>
   <key>com.apple.security.files.downloads.read-write</key>
   <true/>
   <key>com.apple.security.network.client</key>
   <true/>
   ```

2. In Xcode, vai su "Signing & Capabilities" e verifica che:
   - "App Sandbox" sia abilitato
   - "User Selected File" sia impostato su "Read/Write"
   - "Outgoing Connections (Client)" sia abilitato

### Error: Code Signing

**Errore:**
```
resource fork, Finder information, or similar detritus not allowed
Command CodeSign failed with a nonzero exit code
```

**Soluzione:**
1. In Xcode, vai su "Signing & Capabilities"
2. Seleziona "Automatically manage signing"
3. Seleziona il tuo Team (se hai Apple ID)
4. Se non hai un team, imposta "Sign to Run Locally"
5. **Pulisci build:**
   ```bash
   cd macos
   rm -rf build/
   xcodebuild clean -workspace Runner.xcworkspace -scheme Runner
   ```

### Error: CocoaPods non sincronizzato

**Errore:**
```
The sandbox is not in sync with the Podfile.lock
```

**Soluzione:**
```bash
cd macos
pod install
cd ..
```

Poi riprova a buildare in Xcode.

### Error: File Flutter non aggiornati

**Errore:**
```
Unable to load contents of file list: '$HOME/.../macos/Flutter/ephemeral/FlutterInputs.xcfilelist'
Unable to load contents of file list: '$HOME/.../macos/Flutter/ephemeral/FlutterOutputs.xcfilelist'
```

**Soluzione:**
I file `.xcfilelist` vengono generati da Flutter durante il build. Genera i file:

```bash
cd $MYTEAM_REPO_ROOT

# Temporaneamente riabilita macOS desktop per generare i file
flutter config --enable-macos-desktop

# Genera i file necessari
flutter pub get

# Genera i file .xcfilelist (esegue un build parziale)
# Questo può fallire con code signing, ma genera comunque i file necessari
flutter build macos --debug 2>&1 || echo "Build fallito (normale), ma file generati"

# Disabilita nuovamente macOS desktop (opzionale)
flutter config --no-enable-macos-desktop

# Installa CocoaPods
cd macos
pod install
cd ..
```

Poi riapri Xcode e riprova.

### Error: Multiple commands produce (Duplicate Output Files)

**Errore:**
```
Multiple commands produce '$HOME/.../FlutterMacOS.framework/Versions/A/FlutterMacOS'
duplicate output file '$HOME/.../App.framework/Versions/A/App'
```

**Causa:** Due script di build stanno cercando di generare gli stessi file framework.

**Soluzione:**
✅ **Già risolto:** Gli output paths sono configurati correttamente. Lo script "embed" (`3399D490228B24CF009A79C7`) non ha output paths perché non genera file, solo incorpora framework già generati.

Se vedi ancora questo errore:
1. **Pulisci build:**
   ```bash
   cd $MYTEAM_REPO_ROOT
   rm -rf build/macos/
   ```

2. **In Xcode:**
   - Product > Clean Build Folder (⌘⇧K)
   - Poi rebuild (⌘R)

3. **Verifica build phases:**
   - In Xcode, vai su "Build Phases" del target "Runner"
   - Lo script "Flutter Assemble" (`33CC111E2044C6BF0003C045`) DEVE avere output: `Flutter/ephemeral/FlutterOutputs.xcfilelist`
   - Lo script "embed" (`3399D490228B24CF009A79C7`) NON deve avere output paths

### Warning: Run Script Build Phase

**Warning:**
```
Run script build phase 'Run Script' will be run during every build because it does not specify any outputs.
```

**Soluzione:**
Questo warning può apparire per lo script "embed" ma non blocca la build. È normale perché lo script "embed" non genera file, solo incorpora framework.

Se vuoi eliminare il warning:
1. In Xcode, vai su "Build Phases" del target "Runner"
2. Trova la fase "Run Script" (embed)
3. Deseleziona "Based on dependency analysis"

### Error: Network non disponibile

**Verifica:**
1. Il server è in esecuzione: `curl http://localhost:8000/health`
2. Gli entitlements contengono `com.apple.security.network.client`
3. In Xcode "Signing & Capabilities", "Outgoing Connections (Client)" è abilitato

## Workflow Consigliato

### Sviluppo

1. **Modifica codice Dart:**
   ```bash
   # Modifica file in lib/
   ```

2. **Hot Reload in Xcode:**
   - Dopo il primo build, puoi usare hot reload
   - Premi **⌘R** per ricompilare quando necessario

3. **Rebuild completo:**
   - Se modifichi dipendenze o configurazioni native:
   ```bash
   flutter clean
   flutter pub get
   cd macos
   pod install
   cd ..
   ```
   - Poi riapri Xcode e rebuild

### Debug

1. Usa il debugger di Xcode per breakpoint Swift/Objective-C
2. Usa il debugger Flutter per breakpoint Dart
3. Controlla i log in Xcode Console (⌘⇧Y)

## Comandi Rapidi

```bash
# Fix problemi comuni Xcode (consigliato dopo modifiche codice/dipendenze)
./scripts/fix_xcode_issues.sh

# Apri Xcode
open macos/Runner.xcworkspace

# Installa CocoaPods
cd macos && pod install && cd ..

# Pulisci build
cd macos && rm -rf build/ && xcodebuild clean -workspace Runner.xcworkspace -scheme Runner && cd ..

# Verifica server
curl http://localhost:8000/health
```

## Workflow Consigliato dopo Modifiche

Dopo aver modificato il codice Dart o aggiornato le dipendenze:

1. **Esegui lo script di fix:**
   ```bash
   ./scripts/fix_xcode_issues.sh
   ```

2. **Apri Xcode:**
   ```bash
   open macos/Runner.xcworkspace
   ```

3. **Se vedi ancora errori:**
   - Controlla la sezione "Troubleshooting" sopra
   - Verifica i log in Xcode Console (⌘⇧Y)

4. **Build ed esegui:**
   - Premi ⌘R in Xcode

## Note Importanti

1. **Usa sempre `.xcworkspace`**, non `.xcodeproj`
2. **Dopo modifiche a `pubspec.yaml` o problemi Xcode**, esegui:
   ```bash
   ./scripts/fix_xcode_issues.sh
   ```
   Oppure manualmente:
   ```bash
   flutter pub get
   cd macos && pod install && cd ..
   ```
3. **Gli entitlements** richiedono rebuild completo (non hot reload)
4. **Per release**, configura code signing con un team valido
5. **Problemi comuni dopo modifiche codice/dipendenze:**
   - File `.xcfilelist` mancanti → Esegui `./scripts/fix_xcode_issues.sh`
   - PrivacyInfo.xcprivacy error → Lo script lo risolve automaticamente
   - Warning "Run script build phase" → Puoi ignorarlo o deselezionare "Based on dependency analysis"
   - Warning "Update to recommended settings" → Puoi ignorarlo o applicare le modifiche
   - **Error "PhaseScriptExecution failed"** → Vedi sezione dedicata sopra, solitamente risolto da `./scripts/fix_xcode_issues.sh`

## Come Identificare Quale Script Fallisce

Se vedi "Command PhaseScriptExecution failed" ma non sai quale script:

1. **In Xcode Report Navigator:**
   - Premi **⌘9** per aprire Report Navigator
   - Seleziona l'ultimo build fallito
   - Espandi la sezione "Run Script" o "PhaseScriptExecution"
   - Cerca il nome dello script (es. "Flutter Assemble", "[CP] Check Pods Manifest.lock")
   - Leggi il messaggio di errore specifico

2. **Script comuni e come identificarli:**
   - **"Flutter Assemble"** → Errore con `macos_assemble.sh` o file ephemeral mancanti
   - **"[CP] Check Pods Manifest.lock"** → CocoaPods non sincronizzato
   - **"[CP] Embed Pods Frameworks"** → Framework CocoaPods mancanti
   - **"Remove Extended Attributes"** → Raramente fallisce (ha gestione errori)

3. **Log dettagliati:**
   - In Xcode, vai su **View > Debug Area > Activate Console** (⌘⇧Y)
   - Cerca messaggi di errore durante il build
   - Gli errori di script sono solitamente in rosso

