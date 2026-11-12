# Build e Esecuzione Android

## Panoramica

Questa guida spiega come buildare l'app Flutter per Android, generando APK (per installazione diretta) o AAB (Android App Bundle per Google Play Store).

## Prerequisiti

1. **Android Studio** installato
   - Scarica da: https://developer.android.com/studio
   - Durante l'installazione, assicurati di installare:
     - Android SDK
     - Android SDK Platform-Tools
     - Android SDK Build-Tools
     - Android Emulator (opzionale, per test)

2. **Flutter** installato e configurato
   ```bash
   flutter doctor
   ```

3. **Java Development Kit (JDK)** 11 o superiore
   - Android Studio include JDK, ma puoi verificare:
   ```bash
   java -version
   ```

4. **Server** attivo sulla porta 8000 (per test)

## Setup Iniziale

### 1. Verifica Configurazione Flutter

```bash
cd $MYTEAM_REPO_ROOT
flutter doctor
```

**Verifica che Android toolchain sia configurato:**
```
[✓] Android toolchain - develop for Android devices
    • Android SDK at /path/to/Android/sdk
    • Platform android-XX, build-tools XX.X.X
    • Java binary at: /path/to/java
    • Java version: Java XX
```

**Se Android SDK non è trovato:**
1. Apri Android Studio
2. Vai su **Tools > SDK Manager**
3. Installa **Android SDK Platform** (API 33 o superiore)
4. Installa **Android SDK Build-Tools**
5. Configura il path:
   ```bash
   flutter config --android-sdk /path/to/Android/sdk
   ```

### 2. Installa Dipendenze Flutter

```bash
cd $MYTEAM_REPO_ROOT
flutter pub get
```

### 3. Verifica Dispositivi Android

```bash
flutter devices
```

**Dispositivi disponibili:**
- **Emulator Android** (se avviato)
- **Dispositivo fisico Android** (se connesso via USB con USB Debugging abilitato)

**Per abilitare USB Debugging su dispositivo fisico:**
1. Vai su **Impostazioni > Informazioni sul telefono**
2. Tocca **Numero build** 7 volte per abilitare **Opzioni sviluppatore**
3. Vai su **Impostazioni > Opzioni sviluppatore**
4. Abilita **Debug USB**
5. Collega il dispositivo via USB

## Build APK (Android Package)

### APK Debug (per test)

**Build APK debug:**
```bash
cd $MYTEAM_REPO_ROOT
flutter build apk --debug
```

**Output:** `build/app/outputs/flutter-apk/app-debug.apk`

**Installa su dispositivo:**
```bash
flutter install
# Oppure manualmente:
adb install build/app/outputs/flutter-apk/app-debug.apk
```

### APK Release (per distribuzione)

**IMPORTANTE:** Per release, devi configurare il code signing. Vedi sezione [Code Signing](#code-signing-per-release).

**Build APK release:**
```bash
cd $MYTEAM_REPO_ROOT
flutter build apk --release
```

**Output:** `build/app/outputs/flutter-apk/app-release.apk`

**Build APK release split per ABI (riduce dimensione):**
```bash
flutter build apk --release --split-per-abi
```

**Output:**
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` (32-bit ARM)
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (64-bit ARM)
- `build/app/outputs/flutter-apk/app-x86_64-release.apk` (x86_64)

**Vantaggi split:**
- Ogni APK contiene solo il codice nativo per quella architettura
- Dimensioni ridotte (circa 30-40% più piccoli)
- Utente installa solo quello compatibile con il suo dispositivo

## Build AAB (Android App Bundle)

**AAB è richiesto per Google Play Store** (non puoi caricare APK direttamente).

**Build AAB release:**
```bash
cd $MYTEAM_REPO_ROOT
flutter build appbundle --release
```

**Output:** `build/app/outputs/bundle/release/app-release.aab`

**Carica su Google Play Console:**
1. Vai su https://play.google.com/console
2. Seleziona la tua app
3. Vai su **Release > Production** (o **Testing**)
4. Clicca **Crea nuova release**
5. Carica il file `app-release.aab`

## Code Signing for Release

Production signing is controlled by the reviewed release pipeline and owner-authorized release process. Do not generate a replacement production key, use a developer/debug key, copy signing material into the repository, or pass passwords in command arguments. Follow the [canonical production release contract](../../APP/PRODUCTION-RELEASE.md); local debug/QA builds must use their separate identities.

## Esecuzione su Dispositivo/Emulator

### 1. Avvia Emulator (opzionale)

**Da Android Studio:**
1. Apri Android Studio
2. Vai su **Tools > Device Manager**
3. Clicca **Create Device** (se non hai emulator)
4. Seleziona dispositivo e immagine sistema
5. Clicca **Play** per avviare emulator

**Da terminale:**
```bash
flutter emulators
flutter emulators --launch <emulator-id>
```

### 2. Esegui App

**Su dispositivo connesso/emulator:**
```bash
cd $MYTEAM_REPO_ROOT
flutter run -d <device-id>
```

**Lista dispositivi:**
```bash
flutter devices
```

**Esempio output:**
```
sdk gphone64 arm64 (mobile) • emulator-5554 • android-arm64  • Android 13 (API 33)
```

**Esegui:**
```bash
flutter run -d emulator-5554
```

## Configurazione Server URL

Il default delle build è l'API pubblica `https://myteam.simogatti.it`. Per sviluppo locale nell'emulatore Android, passa l'host loopback dell'emulatore senza modificare i sorgenti:

```sh
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=MYTEAM_API_BASE_URL=http://localhost:8000
```

Per un dispositivo fisico o un altro host di sviluppo, usa un endpoint di sviluppo controllato e raggiungibile; non inserire indirizzi personali o privati nel repository.
## Visualizzare Log dell'App

### Metodo 1: Flutter Logs (Consigliato)

Il modo più semplice per vedere i log di Flutter:

```bash
# Vedi tutti i log in tempo reale
flutter logs

# Filtra solo i log della tua app
flutter logs | grep -E "(Upload|Compression|Video)"
```

### Metodo 2: Android Studio Logcat

1. Apri **Android Studio**
2. Avvia l'emulatore o connetti il dispositivo
3. Vai su **View > Tool Windows > Logcat** (o premi `Alt + 6` su Windows/Linux, `Cmd + 6` su macOS)
4. Filtra i log:
   - **Kotlin namespace**: `com.example.myteam_video_app`; production application ID: `it.simogatti.myteam` (QA-only builds retain `com.example.myteam_video_app`) (see `docs/APP/RELEASE-BASELINE.md`).
   - **Tag**: Cerca per `flutter`, `MyTeam`, o tag personalizzati
   - **Level**: Seleziona il livello (Verbose, Debug, Info, Warn, Error)

### Metodo 3: ADB Logcat (Terminale)

```bash
# Vedi tutti i log
adb logcat

# Filtra solo log Flutter
adb logcat | grep flutter

# Filtra log specifici (Upload, Compression, etc.)
adb logcat | grep -E "(Upload|Compression|Video|MyTeam)"

# Salva log su file
adb logcat > app_logs.txt

# Pulisci log precedenti e vedi solo nuovi
adb logcat -c && adb logcat
```

### Metodo 4: Flutter DevTools (Avanzato)

1. Avvia l'app in debug mode:
   ```bash
   flutter run
   ```
2. Apri il browser su: `http://localhost:9100` (o l'URL mostrato nel terminale)
3. Vai su **Logging** per vedere i log in tempo reale

### Filtri Utili per Debug

```bash
# Solo errori
adb logcat *:E

# Solo log Flutter
adb logcat | grep flutter

# Solo log della tua app (package name)
adb logcat | grep "it.simogatti.myteam"

# Combinazione: Flutter + Errori
adb logcat | grep -E "(flutter|ERROR)"
```

### Log Specifici per Upload/Compressione

I log che abbiamo aggiunto usano questi prefissi:
- `🎬 [Compression]` - Log compressione
- `📤 [Upload]` - Log upload
- `✅` - Successo
- `❌` - Errore
- `⚠️` - Warning

Per vedere solo questi:
```bash
adb logcat | grep -E "(Compression|Upload|✅|❌|⚠️)"
```

## Troubleshooting

### Error: Android SDK non trovato

**Errore:**
```
Unable to locate Android SDK.
```

**Soluzione:**
1. Installa Android Studio
2. Apri **Tools > SDK Manager**
3. Installa **Android SDK Platform** (API 33+)
4. Configura path:
   ```bash
   flutter config --android-sdk $ANDROID_HOME
   # Oppure:
   flutter config --android-sdk /path/to/Android/sdk
   ```

### Error: Gradle Build Failed

**Errore:**
```
Gradle build failed
```

**Soluzione:**
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk --debug
```

### Error: Code Signing

**Errore:**
```
Keystore file not found
```

**Soluzione:**
1. Verifica che `android/key.properties` esista
2. Verifica che il path in `storeFile` sia corretto (usa path assoluto)
3. Verifica che il keystore esista nel path specificato

### Error: MinSdkVersion

**Errore:**
```
minSdkVersion is too low
```

**Soluzione:**
Verifica `android/app/build.gradle.kts`:
```kotlin
minSdk = 21  // Android 5.0 (Lollipop) - minimo supportato da Flutter
```

### Error: Permessi Internet

**Se l'app non può connettersi al server:**

Verifica `android/app/src/main/AndroidManifest.xml`:
```xml
<manifest ...>
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <!-- ... resto del manifest ... -->
</manifest>
```

### Error: FFmpeg non funziona

**L'app usa `ffmpeg_kit_flutter_new` che include FFmpeg v6.0.2-LTS:**
- Non è necessario installare FFmpeg separatamente
- Il pacchetto include i binari per Android
- Se ci sono problemi, verifica che il pacchetto sia aggiornato:
  ```bash
  flutter pub upgrade ffmpeg_kit_flutter_new
  ```

## Comandi Rapidi

```bash
# Lista dispositivi Android
flutter devices

# Build APK debug
flutter build apk --debug

# Build APK release
flutter build apk --release

# Build APK release split per ABI
flutter build apk --release --split-per-abi

# Build AAB release (per Google Play)
flutter build appbundle --release

# Esegui su dispositivo
flutter run -d <device-id>

# Pulizia build
flutter clean
```

## File di Output

**APK Debug:**
- `build/app/outputs/flutter-apk/app-debug.apk`

**APK Release:**
- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` (split)
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (split)
- `build/app/outputs/flutter-apk/app-x86_64-release.apk` (split)

**AAB Release:**
- `build/app/outputs/bundle/release/app-release.aab`

## Note Importanti

1. **Keystore:** Non perdere mai il keystore! Se lo perdi, non potrai aggiornare l'app su Google Play Store.

2. **Version Code:** Flutter gestisce automaticamente `versionCode` e `versionName` da `pubspec.yaml`:
   ```yaml
   version: 0.1.0+1  # versionName+versionCode
   ```

3. **ProGuard:** Per release, considera di abilitare ProGuard per ridurre la dimensione dell'APK/AAB.

4. **Testing:** Testa sempre l'APK/AAB su dispositivi reali prima di pubblicare su Google Play Store.

