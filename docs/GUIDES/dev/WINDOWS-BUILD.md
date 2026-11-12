# Build e Esecuzione Windows

## Panoramica

Questa guida spiega come buildare ed eseguire l'app Flutter su Windows.

## Prerequisiti

1. **Windows 10 o superiore** (Windows 11 consigliato)
2. **Flutter SDK** installato e configurato
3. **Visual Studio 2022** con componenti Windows desktop development
4. **Server** attivo sulla porta 8000 (per testing)

## Setup Iniziale

### 1. Verifica Flutter

Apri PowerShell o Command Prompt e verifica:

```bash
flutter --version
flutter doctor
```

**Output atteso:**
- Flutter SDK installato
- Windows toolchain configurato
- Visual Studio installato

### 2. Abilita Windows Desktop Support

Se non già abilitato:

```bash
flutter config --enable-windows-desktop
```

Verifica che sia abilitato:

```bash
flutter config
# Dovrebbe mostrare: enable-windows-desktop: true
```

### 3. Verifica Visual Studio

Flutter richiede Visual Studio con i componenti per sviluppo Windows desktop:

1. Apri **Visual Studio Installer**
2. Clicca **Modifica** su Visual Studio 2022
3. Verifica che siano installati:
   - ✅ **Desktop development with C++**
   - ✅ **Windows 10/11 SDK** (versione più recente)
   - ✅ **MSVC v143 - VS 2022 C++ x64/x86 build tools**

Se mancanti, installali e riavvia il computer.

### 4. Genera File Windows (se necessario)

Se la cartella `windows/` non esiste:

```bash
cd C:\path\to\MyTeam  # Sostituisci con il tuo percorso
flutter create --platforms=windows .
```

**Nota:** Questo comando genera solo i file necessari senza sovrascrivere il codice esistente.

## Build e Esecuzione

### Build Debug (Sviluppo)

```bash
cd C:\path\to\MyTeam  # Sostituisci con il tuo percorso
flutter build windows --debug
```

**Output:**
- File eseguibile: `build/windows/x64/runner/Debug/MyTeam.exe`
- Esegui direttamente il file `.exe` o usa:

```bash
flutter run -d windows
```

### Build Release (Produzione)

```bash
cd C:\path\to\MyTeam  # Sostituisci con il tuo percorso
flutter build windows --release
```

**Output:**
- File eseguibile: `build/windows/x64/runner/Release/MyTeam.exe`
- Questo è il file ottimizzato per distribuzione

### Esecuzione Diretta

Dopo il build, puoi eseguire direttamente:

```bash
# Debug
.\build\windows\x64\runner\Debug\MyTeam.exe

# Release
.\build\windows\x64\runner\Release\MyTeam.exe
```

## Configurazione Server URL

Il default è l'API pubblica `https://myteam.simogatti.it`. Per sviluppo locale, configura l'endpoint al momento dell'avvio:

```powershell
flutter run --dart-define=MYTEAM_API_BASE_URL=http://localhost:8000
```

Non inserire endpoint privati o credenziali nel repository.
## Distribuzione

### Opzione 1: Distribuzione Manuale

1. Builda in release:
   ```bash
   flutter build windows --release
   ```

2. Copia l'intera cartella `build/windows/x64/runner/Release/` su un altro computer Windows

3. Esegui `MyTeam.exe` direttamente

**Nota:** L'app è standalone e non richiede installazione.

### Opzione 2: Creare Installer (Opzionale)

Per creare un installer Windows, puoi usare:
- **Inno Setup** (gratuito, open source)
- **NSIS** (Nullsoft Scriptable Install System)
- **WiX Toolset** (Microsoft)

Vedi la sezione "Creare Installer" sotto per dettagli.

## Troubleshooting

### Errore: "Windows toolchain not found"

**Causa:** Visual Studio non installato o componenti mancanti.

**Soluzione:**
1. Installa Visual Studio 2022 con componenti Windows desktop development
2. Riavvia il computer
3. Esegui `flutter doctor` per verificare

### Errore: "Unable to find MSBuild"

**Causa:** MSBuild non nel PATH o Visual Studio non configurato correttamente.

**Soluzione:**
1. Apri Visual Studio Installer
2. Clicca **Modifica** su Visual Studio 2022
3. Verifica che **Desktop development with C++** sia installato
4. Riavvia PowerShell/Command Prompt
5. Esegui `flutter doctor` per verificare

### Errore: "Unable to find Windows SDK"

**Causa:** Windows SDK non installato.

**Soluzione:**
1. Apri Visual Studio Installer
2. Clicca **Modifica** su Visual Studio 2022
3. Installa **Windows 10/11 SDK** (versione più recente)
4. Riavvia il computer

### Build Fallisce con Errori C++

**Causa:** Dipendenze native non compilate correttamente.

**Soluzione:**
```bash
# Pulisci build
flutter clean

# Reinstalla dipendenze
flutter pub get

# Rebuild
flutter build windows --release
```

### App Non Si Avvia

**Causa:** Dipendenze runtime mancanti o problemi di configurazione.

**Soluzione:**
1. Verifica che il server sia raggiungibile
2. Controlla i log in `build/windows/x64/runner/Release/` (se presenti)
3. Esegui da PowerShell per vedere errori:
   ```powershell
   .\build\windows\x64\runner\Release\MyTeam.exe
   ```

### FFmpeg non funziona (compressione)

La compressione Windows avvia FFmpeg esterno installato separatamente; `ffmpeg_kit_flutter_new` non fornisce qui il binario Windows. Il playback usa invece `media_kit_libs_windows_video`. Consultare [le note sulle licenze di terze parti](../../APP/THIRD-PARTY-LICENSES.md) per i componenti verificati e le verifiche native ancora aperte.

## Creare Installer Windows (Opzionale)

### Usando Inno Setup (Consigliato)

1. **Scarica Inno Setup**: https://jrsoftware.org/isdl.php

2. **Crea script installer** (`installer.iss`):
   ```iss
   [Setup]
   AppName=MyTeam Video
   AppVersion=0.1.0
   DefaultDirName={pf}\MyTeam
   DefaultGroupName=MyTeam
   OutputDir=installer
   OutputBaseFilename=MyTeam-Setup
   Compression=lzma
   SolidCompression=yes

   [Files]
   Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

   [Icons]
   Name: "{group}\MyTeam"; Filename: "{app}\MyTeam.exe"
   Name: "{commondesktop}\MyTeam"; Filename: "{app}\MyTeam.exe"
   ```

3. **Compila installer**:
   - Apri Inno Setup Compiler
   - Carica `installer.iss`
   - Clicca **Build > Compile**

4. **Output**: `installer/MyTeam-Setup.exe`

## Comandi Rapidi

```bash
# Verifica configurazione
flutter doctor

# Lista dispositivi disponibili
flutter devices

# Build debug
flutter build windows --debug

# Build release
flutter build windows --release

# Esegui direttamente
flutter run -d windows

# Pulisci build
flutter clean

# Aggiorna dipendenze
flutter pub get
```

## Build con GitHub Actions (Consigliato per macOS)

Se sviluppi su macOS e vuoi buildare per Windows senza installare Visual Studio, usa **GitHub Actions**:

1. Pusha il codice su GitHub
2. Vai su **Actions** → **Build Flutter App** → **Run workflow**
3. Scegli piattaforma `windows` e tipo `release`
4. Scarica gli artefatti dopo il build

Vedi [GITHUB-ACTIONS.md](GITHUB-ACTIONS.md) per dettagli completi.

## Note Importanti

1. **Prima build**: La prima build può richiedere diversi minuti (compilazione dipendenze native)

2. **Antivirus**: Alcuni antivirus possono bloccare l'esecuzione. Aggiungi eccezione se necessario.

3. **Firewall**: L'app si connette al server. Verifica che il firewall non blocchi la connessione.

4. **Path**: Usa sempre path assoluti o relativi corretti per Windows (backslash `\` o slash `/`)

5. **Dipendendenze**: Tutte le dipendenze native sono incluse nel build. Non è necessario installare nulla separatamente.

## Verifica Build

Dopo il build, verifica che l'app funzioni:

1. **Esegui l'app**: `.\build\windows\x64\runner\Release\MyTeam.exe`

2. **Test upload**: Carica un video e verifica che funzioni

3. **Test compressione**: Verifica che la compressione video funzioni

4. **Test connessione**: Verifica che l'app si connetta al server

## Supporto

Per problemi specifici:
- Vedi [BUILD-TROUBLESHOOTING.md](BUILD-TROUBLESHOOTING.md) per problemi comuni
- Vedi [QUICK-START.md](QUICK-START.md) per setup base
- Verifica `flutter doctor` per problemi di configurazione

