# Dipendenze Esterne del Progetto

Questo documento elenca tutte le dipendenze esterne (programmi e tool) necessarie per sviluppare, buildare ed eseguire il progetto MyTeam Video.

## 📱 App Flutter

### Dipendenze Obbligatorie

#### 1. **Flutter SDK**
- **Versione:** 3.24.5+ (stabile)
- **Descrizione:** Framework Flutter per sviluppo cross-platform
- **Installazione:** https://flutter.dev/docs/get-started/install
- **Verifica:** `flutter --version`
- **Piattaforme:** Tutte (Android, macOS, Windows)

#### 2. **Dart SDK**
- **Incluso in:** Flutter SDK
- **Versione:** 3.5.0+ (incluso con Flutter 3.24.5)
- **Verifica:** `dart --version`

### Dipendenze per Build Android

#### 3. **Android Studio**
- **Descrizione:** IDE ufficiale per sviluppo Android
- **Include:** Android SDK, Android SDK Platform-Tools, Android SDK Build-Tools
- **Installazione:** https://developer.android.com/studio
- **Verifica:** Apri Android Studio > Tools > SDK Manager
- **Piattaforme:** Windows, macOS, Linux

#### 4. **Android SDK**
- **Incluso in:** Android Studio
- **Componenti richiesti:**
  - Android SDK Platform (API 33+)
  - Android SDK Build-Tools
  - Android SDK Platform-Tools
- **Verifica:** `flutter doctor`
- **Piattaforme:** Windows, macOS, Linux

#### 5. **Java Development Kit (JDK)**
- **Versione:** JDK 11 o superiore
- **Incluso in:** Android Studio (JDK incluso)
- **Verifica:** `java -version`
- **Piattaforme:** Windows, macOS, Linux

#### 6. **Gradle**
- **Incluso in:** Android SDK (gestito automaticamente)
- **Versione:** Gestita automaticamente da Flutter
- **Verifica:** `cd android && ./gradlew --version`
- **Piattaforme:** Windows, macOS, Linux

### Dipendenze per Build macOS

#### 7. **Xcode**
- **Versione:** 14.0 o superiore
- **Descrizione:** IDE Apple per sviluppo macOS
- **Installazione:** App Store (macOS)
- **Verifica:** `xcodebuild -version`
- **Piattaforme:** Solo macOS

#### 8. **CocoaPods**
- **Descrizione:** Dependency manager per progetti macOS
- **Installazione:** `brew install cocoapods` (richiede Homebrew)
- **Verifica:** `pod --version`
- **Piattaforme:** Solo macOS
- **Nota:** Necessario per gestire dipendenze native macOS

### Dipendenze per Build Windows

#### 9. **Visual Studio 2022**
- **Versione:** Community Edition o superiore
- **Componenti richiesti:**
  - Desktop development with C++
  - Windows 10/11 SDK (versione più recente)
  - MSVC v143 - VS 2022 C++ x64/x86 build tools
- **Installazione:** https://visualstudio.microsoft.com/downloads/
- **Verifica:** Apri Visual Studio Installer
- **Piattaforme:** Solo Windows

#### 10. **Windows SDK**
- **Incluso in:** Visual Studio 2022
- **Versione:** Windows 10/11 SDK (più recente)
- **Verifica:** Visual Studio Installer > Modifica > Desktop development with C++
- **Piattaforme:** Solo Windows

### Dipendenze per Compressione Video (Windows)

#### 11. **FFmpeg** (Solo Windows)
- **Descrizione:** Tool per compressione video hardware
- **Versione:** Qualsiasi versione recente (6.0+ consigliata)
- **Installazione:** 
  - **Automatica:** L'app offre installazione guidata quando necessario
  - **Manuale:** https://www.gyan.dev/ffmpeg/builds/ (Windows)
- **Verifica:** `ffmpeg -version`
- **Piattaforme:** Solo Windows (per compressione)
- **Nota:** 
  - Android/macOS usano `ffmpeg_kit_flutter_new` (incluso nel package)
  - Windows richiede FFmpeg installato separatamente per compressione hardware
  - L'app verifica automaticamente e offre installazione guidata

### Dipendenze Opzionali

#### 12. **Git**
- **Descrizione:** Version control system
- **Installazione:** https://git-scm.com/downloads
- **Verifica:** `git --version`
- **Piattaforme:** Tutte
- **Nota:** Opzionale, utile per clonare repository

#### 13. **Homebrew** (macOS)
- **Descrizione:** Package manager per macOS
- **Installazione:** `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
- **Verifica:** `brew --version`
- **Piattaforme:** Solo macOS
- **Nota:** Utile per installare CocoaPods e FFmpeg (se necessario)

#### 14. **Chocolatey** (Windows)
- **Descrizione:** Package manager per Windows
- **Installazione:** https://chocolatey.org/install
- **Verifica:** `choco --version`
- **Piattaforme:** Solo Windows
- **Nota:** Opzionale, utile per installare FFmpeg (se necessario)

---

## 🖥️ Server Python

### Dipendenze Obbligatorie

#### 1. **Python**
- **Versione:** 3.11 o 3.12 (⚠️ **NON usare 3.13+**)
- **Descrizione:** Linguaggio di programmazione per il server
- **Installazione:** 
  - **Windows:** https://www.python.org/downloads/release/python-3120/
  - **macOS:** `brew install python@3.12` (con Homebrew)
  - **Linux:** `sudo apt-get install python3.12`
- **Verifica:** `python --version` o `python3 --version`
- **Piattaforme:** Tutte
- **⚠️ IMPORTANTE:** Python 3.13 e 3.14 sono troppo recenti. Molte librerie (come `pydantic-core`) non hanno ancora wheel precompilati per Windows, causando errori di compilazione.

#### 2. **FFmpeg**
- **Descrizione:** Tool per estrazione metadata e generazione thumbnail
- **Versione:** Qualsiasi versione recente (6.0+ consigliata)
- **Installazione:**
  - **Windows:** https://www.gyan.dev/ffmpeg/builds/ (ffmpeg-release-essentials.zip)
  - **macOS:** `brew install ffmpeg`
  - **Linux:** `sudo apt-get install ffmpeg`
- **Verifica:** `ffmpeg -version`
- **Piattaforme:** Tutte
- **Nota:** Include anche FFprobe (necessario per estrazione metadata)

#### 3. **FFprobe**
- **Descrizione:** Tool per analisi file video (estrazione metadata)
- **Incluso in:** FFmpeg (installazione FFmpeg include FFprobe)
- **Verifica:** `ffprobe -version`
- **Piattaforme:** Tutte
- **Nota:** Installato automaticamente con FFmpeg

### Dipendenze Opzionali (Process Manager)

#### 4. **PM2** (Windows/macOS/Linux)
- **Descrizione:** Process manager per applicazioni Node.js (può gestire anche Python)
- **Installazione:** 
  - Richiede Node.js: https://nodejs.org/
  - Poi: `npm install pm2 -g`
- **Verifica:** `pm2 --version`
- **Piattaforme:** Tutte
- **Nota:** Utile per gestire il server come servizio, con auto-restart

#### 5. **NSSM** (Windows)
- **Descrizione:** Non-Sucking Service Manager per Windows
- **Installazione:** https://nssm.cc/download
- **Verifica:** `nssm status MyTeamVideoServer`
- **Piattaforme:** Solo Windows
- **Nota:** Alternativa a PM2 per Windows, crea servizio Windows nativo

#### 6. **Node.js** (solo se si usa PM2)
- **Versione:** LTS (Long Term Support)
- **Installazione:** https://nodejs.org/
- **Verifica:** `node --version`
- **Piattaforme:** Tutte
- **Nota:** Necessario solo se si usa PM2 come process manager

---

## 📋 Riepilogo per Piattaforma

### Sviluppo App (macOS)

**Obbligatorie:**
- ✅ Flutter SDK
- ✅ Xcode
- ✅ CocoaPods

**Opzionali:**
- ⚪ Homebrew (per installare CocoaPods)
- ⚪ Git

### Sviluppo App (Windows)

**Obbligatorie:**
- ✅ Flutter SDK
- ✅ Visual Studio 2022
- ✅ FFmpeg (per compressione video)

**Opzionali:**
- ⚪ Chocolatey (per installare FFmpeg)
- ⚪ Git

### Sviluppo App (Android)

**Obbligatorie:**
- ✅ Flutter SDK
- ✅ Android Studio
- ✅ Android SDK
- ✅ JDK

**Opzionali:**
- ⚪ Git

### Server (Windows)

**Obbligatorie:**
- ✅ Python 3.11 o 3.12
- ✅ FFmpeg (include FFprobe)

**Opzionali:**
- ⚪ PM2 (process manager)
- ⚪ NSSM (alternativa a PM2 per Windows)
- ⚪ Node.js (solo se si usa PM2)

### Server (macOS/Linux)

**Obbligatorie:**
- ✅ Python 3.11 o 3.12
- ✅ FFmpeg (include FFprobe)

**Opzionali:**
- ⚪ PM2 (process manager)
- ⚪ Node.js (solo se si usa PM2)

---

## 🔍 Verifica Installazione

### App Flutter

```bash
# Verifica Flutter
flutter doctor

# Verifica Android SDK
flutter doctor --android-licenses

# Verifica CocoaPods (macOS)
pod --version

# Verifica FFmpeg (Windows)
ffmpeg -version
```

### Server

```bash
# Verifica Python
python --version  # Dovrebbe mostrare 3.11.x o 3.12.x

# Verifica FFmpeg
ffmpeg -version
ffprobe -version

# Verifica dipendenze Python
cd server
python -m pip list
```

---

## ⚠️ Note Importanti

1. **Python 3.13+ non supportato:** Usa Python 3.11 o 3.12 per evitare problemi di compilazione con `pydantic-core` su Windows.

2. **FFmpeg su Windows (App):** 
   - Richiesto solo per compressione video
   - L'app offre installazione guidata automatica quando necessario
   - Se non installato, l'app mostra dialog con opzioni di installazione

3. **FFmpeg su Server:**
   - Obbligatorio per estrazione metadata e generazione thumbnail
   - Deve essere installato manualmente e configurato nel `.env`

4. **Android SDK:**
   - Incluso in Android Studio
   - Flutter gestisce automaticamente la configurazione

5. **CocoaPods (macOS):**
   - Necessario per gestire dipendenze native macOS
   - Installato automaticamente durante `pod install`

6. **Visual Studio (Windows):**
   - Necessario per compilare codice C++ nativo
   - Community Edition è gratuita e sufficiente

---

## 🆘 Troubleshooting

### FFmpeg non trovato (App Windows)
- L'app mostra automaticamente un dialog per installazione guidata
- Oppure installa manualmente: https://www.gyan.dev/ffmpeg/builds/

### Python 3.13+ installato (Server)
- Disinstalla Python 3.13/3.14
- Installa Python 3.12: https://www.python.org/downloads/release/python-3120/

### CocoaPods non trovato (macOS)
- Installa Homebrew: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
- Installa CocoaPods: `brew install cocoapods`

### Android SDK non trovato
- Apri Android Studio
- Vai su Tools > SDK Manager
- Installa Android SDK Platform e Build-Tools

### Visual Studio non trovato (Windows)
- Scarica Visual Studio 2022 Community: https://visualstudio.microsoft.com/downloads/
- Durante installazione, seleziona "Desktop development with C++"

