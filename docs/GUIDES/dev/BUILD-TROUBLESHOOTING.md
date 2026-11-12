# Troubleshooting Build Failures

## Problema

Dopo modifiche al codice, le build Android e macOS falliscono con errori vari.

## Cause Comuni

1. **Cache Flutter non aggiornata** - `flutter clean` non eseguito
2. **Dipendenze non aggiornate** - `flutter pub get` non eseguito dopo modifiche
3. **CocoaPods non sincronizzato** (macOS) - Podfile.lock non aggiornato
4. **Gradle cache corrotta** (Android) - Cache Gradle non pulita
5. **File generati obsoleti** - File generati da Flutter non aggiornati

## Soluzione Rapida

### Script Automatico (Consigliato)

Usa lo script di pulizia automatica:

```bash
# Pulizia completa
./scripts/clean_build.sh

# Oppure rebuild completo
./scripts/rebuild_all.sh
```

### Soluzione Manuale

Se preferisci farlo manualmente:

#### 1. Pulizia Base Flutter

```bash
flutter clean
flutter pub get
```

#### 2. Per macOS

```bash
cd macos
rm -rf Pods/ Podfile.lock
pod install --repo-update
cd ..
```

**Nota:** iOS non è supportato in questo progetto. Gli script saltano automaticamente iOS.

#### 3. Per Android

```bash
cd android
./gradlew clean
cd ..
```

#### 4. Verifica

```bash
flutter analyze  # Verifica errori di codice
flutter doctor   # Verifica configurazione
```

## Quando Eseguire la Pulizia

Esegui la pulizia quando:

- ✅ Modifichi file Dart principali
- ✅ Aggiungi/rimuovi dipendenze in `pubspec.yaml`
- ✅ Modifichi configurazioni native (AndroidManifest.xml, Info.plist, ecc.)
- ✅ Aggiorni Flutter SDK
- ✅ Cambi configurazioni di build (signing, permissions, ecc.)
- ✅ Vedi errori di build inspiegabili

## Prevenzione

### 1. Esegui sempre `flutter pub get` dopo modifiche

```bash
# Dopo ogni modifica a pubspec.yaml o file Dart
flutter pub get
```

### 2. Usa `flutter analyze` prima di buildare

```bash
# Verifica errori prima di buildare
flutter analyze
```

### 3. Mantieni dipendenze aggiornate

```bash
# Verifica dipendenze obsolete
flutter pub outdated

# Aggiorna dipendenze (con cautela)
flutter pub upgrade
```

### 4. Per macOS: Mantieni CocoaPods sincronizzato

```bash
# Dopo modifiche a dipendenze native
cd macos && pod install && cd ..
```

## Errori Specifici

### macOS: "Command PhaseScriptExecution failed"

**Causa**: Script di build Flutter non trovati o cache corrotta

**Soluzione**:
```bash
flutter clean
cd macos && pod install && cd ..
flutter pub get
```

### macOS: "CodeSign failed"

**Causa**: Problemi con code signing o file con attributi estesi

**Soluzione**:
```bash
# Rimuovi attributi estesi
xattr -cr .
flutter clean
flutter pub get
```

### Android: "GeneratedPluginRegistrant duplicated"

**Causa**: File generati duplicati o cache corrotta

**Soluzione**:
```bash
flutter clean
flutter pub get
cd android && ./gradlew clean && cd ..
```

### Android: "Gradle build failed"

**Causa**: Cache Gradle corrotta o dipendenze non sincronizzate

**Soluzione**:
```bash
cd android
./gradlew clean
./gradlew --stop  # Ferma daemon Gradle
rm -rf .gradle build/
cd ..
flutter clean
flutter pub get
```

## Workflow Consigliato

1. **Modifica codice**
2. **Esegui `flutter analyze`** - Verifica errori
3. **Esegui `flutter pub get`** - Aggiorna dipendenze
4. **Se necessario, esegui `./scripts/clean_build.sh`** - Pulizia completa
5. **Build** - `flutter build apk` o `flutter build macos`

## Script Disponibili

- **`scripts/clean_build.sh`** - Pulizia completa del progetto
- **`scripts/rebuild_all.sh`** - Pulizia + analisi + verifica

## Note

- La pulizia completa può richiedere alcuni minuti
- Dopo `flutter clean`, la prima build sarà più lenta (normale)
- Non eseguire pulizia durante sviluppo attivo (solo quando necessario)

