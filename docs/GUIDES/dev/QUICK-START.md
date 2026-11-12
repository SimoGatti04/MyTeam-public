# Quick Start Guide - App Flutter


I comandi che richiedono il percorso del checkout usano `$MYTEAM_REPO_ROOT`; impostalo al percorso locale scelto per questa copia del repository.
## Prerequisiti

1. **Server attivo** sulla porta 8000
2. **Flutter** installato e configurato
3. **CocoaPods** installato - `brew install cocoapods` (per macOS)
4. **Dispositivo** disponibile (emulatore Android, macOS, o Windows)

## Avvio App

### 1. Verifica Server

Assicurati che il server sia in esecuzione:

```bash
cd server
source venv/bin/activate
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

**Verifica rapida:**
```bash
curl http://localhost:8000/health
# Dovrebbe restituire: {"status":"healthy"}
```

### 2. Avvia App

#### ✅ Opzione 1: macOS (Consigliato - Più Semplice)
```bash
cd $MYTEAM_REPO_ROOT
flutter devices  # Lista dispositivi disponibili
flutter run -d macos
```

**Vantaggi:**
- Nessun problema di code signing (debug)
- Più veloce da compilare
- Funziona immediatamente
- `localhost:8000` funziona direttamente

#### Opzione 2: Android Emulator
```bash
flutter devices  # Lista dispositivi
flutter run -d <device-id>  # Es: emulator-5554
```

**Nota:** Richiede Android SDK e emulatore configurato.

#### Opzione 3: macOS Desktop (Usa Xcode)

**IMPORTANTE:** Per macOS, usa Xcode direttamente invece di Flutter CLI. Vedi [XCODE-BUILD.md](XCODE-BUILD.md) per istruzioni dettagliate.

### 3. Configurazione Server URL

Il default è l'API pubblica `https://myteam.simogatti.it`. Per un emulatore Android con servizio locale, esegui:

```sh
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=MYTEAM_API_BASE_URL=http://localhost:8000
```

Per altri ambienti, configura l'URL del servizio di sviluppo al momento dell'avvio; non modificare né committare endpoint privati.
## Test Upload

1. Avvia l'app (vedi sopra)
2. Naviga alla schermata "Upload" (tab in basso)
3. Seleziona un video (bottone "Choose Video File")
4. Configura compressione (opzionale):
   - Risoluzione: 480p, 720p, 1080p, 1440p, 2160p, Original
   - Framerate: 24, 30, 60, 120 fps
5. Clicca "Upload Video"
6. Monitora il progresso durante:
   - Compressione (se applicata)
   - Upload al server

## Troubleshooting

### Server non raggiungibile
- Verifica che il server sia in esecuzione: `curl http://localhost:8000/health`
- Controlla firewall/antivirus
- Per Android: usa `YOUR_DEV_API_HOST:8000` invece di `localhost:8000`
- Per dispositivi fisici: usa l'IP del computer invece di `localhost`

### FFmpeg non trovato (compressione)
- L'app usa `ffmpeg_kit_flutter_new` che include FFmpeg v6.0.2-LTS
- Non è necessario installare FFmpeg separatamente sull'app
- Il pacchetto include i binari per Android, macOS e Windows

### CocoaPods Error
- Installa CocoaPods: `brew install cocoapods`
- Verifica installazione: `pod --version`

### Build Error
Se vedi errori di build:
```bash
flutter clean
rm -rf build/ macos/Pods/
flutter pub get
cd macos && pod install && cd ..
flutter run -d <device-id>
```

## Comandi Rapidi

```bash
# Lista dispositivi disponibili
flutter devices

# Avvia su macOS (consigliato)
flutter run -d macos

# Verifica server
curl http://localhost:8000/health
```
