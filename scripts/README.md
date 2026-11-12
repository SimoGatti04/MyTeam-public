# Script di Build

Script utili per gestire build e troubleshooting del progetto Flutter.

## Script Disponibili

### `clean_build.sh`

Pulisce completamente il progetto Flutter e ricostruisce le dipendenze.

**Cosa fa:**
- Esegue `flutter clean`
- Rimuove directory build e cache
- Esegue `flutter pub get`
- Pulisce e reinstalla CocoaPods (macOS)
- Pulisce cache Gradle (Android)

**Quando usarlo:**
- Dopo modifiche significative al codice
- Quando le build falliscono inspiegabilmente
- Dopo aggiornamenti di Flutter SDK
- Dopo modifiche a dipendenze native

**Uso:**
```bash
./scripts/clean_build.sh
```

### `rebuild_all.sh`

Pulizia completa + analisi codice + verifica.

**Cosa fa:**
- Esegue `clean_build.sh`
- Esegue `flutter analyze` per verificare errori
- Mostra comandi utili per build

**Quando usarlo:**
- Prima di commit importanti
- Dopo modifiche estese al codice
- Per verificare che tutto sia a posto

**Uso:**
```bash
./scripts/rebuild_all.sh
```

## Workflow Consigliato

### Sviluppo Normale

```bash
# 1. Modifica codice
# 2. Verifica errori
flutter analyze

# 3. Aggiorna dipendenze (se necessario)
flutter pub get

# 4. Build
flutter build apk --release
```

### Dopo Modifiche Importanti

```bash
# 1. Modifica codice
# 2. Esegui pulizia completa
./scripts/clean_build.sh

# 3. Build
flutter build apk --release
```

### Prima di Commit

```bash
# 1. Rebuild completo con verifica
./scripts/rebuild_all.sh

# 2. Se tutto OK, commit
git add .
git commit -m "Your message"
```

## Troubleshooting

Se gli script falliscono:

1. **Verifica permessi:**
   ```bash
   chmod +x scripts/*.sh
   ```

2. **Esegui manualmente:**
   ```bash
   flutter clean
   flutter pub get
   ```

3. **Per macOS, verifica CocoaPods:**
   ```bash
   cd macos && pod install && cd ..
   ```

## Piattaforme Supportate

Questi script supportano:
- ✅ **Android** - Build APK e AAB
- ✅ **macOS** - Build app desktop
- ✅ **Windows** - Build app desktop
- ❌ **iOS** - Non supportato (rimosso dagli script)

4. **Per Android, verifica Gradle:**
   ```bash
   cd android && ./gradlew clean && cd ..
   ```

## Note

- Gli script richiedono Flutter SDK installato
- Per macOS, richiede CocoaPods installato
- Per Android, richiede Android SDK configurato
- La pulizia completa può richiedere alcuni minuti

