# Build macOS - Soluzione Problema CocoaPods

## Problema
CocoaPods 1.16.2 ha un bug noto con Xcode 26.1.1 che impedisce la lettura del file `project.pbxproj` quando contiene `shellScript` definiti come array.

**Errore:**
```
RuntimeError - [Xcodeproj] Type checking error: got `Array` for attribute: Attribute `shellScript`
```

## Soluzione Temporanea

### Opzione 1: Usa Xcode direttamente (Consigliato)

1. Apri il progetto in Xcode:
   ```bash
   open macos/Runner.xcworkspace
   ```

2. In Xcode:
   - Product → Clean Build Folder (Shift+Cmd+K)
   - Product → Build (Cmd+B)
   - Product → Run (Cmd+R)

Xcode gestisce meglio il formato del progetto rispetto a CocoaPods.

### Opzione 2: Aggiorna xcodeproj gem

```bash
gem update xcodeproj
cd macos
pod install
```

### Opzione 3: Usa Flutter build (se funziona)

```bash
flutter clean
flutter pub get
flutter run -d macos
```

Nota: Anche `flutter run` potrebbe fallire se CocoaPods non riesce a installare i pod.

## Workaround Permanente

Il problema verrà risolto quando CocoaPods/xcodeproj verrà aggiornato per supportare Xcode 26.1.1. Monitora:
- https://github.com/CocoaPods/CocoaPods/issues/12794

## File XCFileList Mancanti

Se vedi errori sui file XCFileList mancanti, usa lo script fornito:

```bash
./scripts/fix_macos_xcfilelist.sh
```

Oppure creali manualmente:

```bash
# File CocoaPods
mkdir -p "macos/Pods/Target Support Files/Pods-Runner"
touch "macos/Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-Debug-input-files.xcfilelist"
touch "macos/Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-Debug-output-files.xcfilelist"

# File Flutter
mkdir -p macos/Flutter/ephemeral
touch macos/Flutter/ephemeral/FlutterInputs.xcfilelist
touch macos/Flutter/ephemeral/FlutterOutputs.xcfilelist
```

**Nota:** Questi file sono vuoti e servono solo per permettere la build. Per una build completa, devi risolvere il problema CocoaPods o usare Xcode direttamente.

## Soluzioni Trovate Online

Basandosi su issue #12794 e discussioni della community:

1. **Workaround più comune:** Usa Xcode direttamente invece di CocoaPods
2. **Aggiorna xcodeproj gem:** `gem update xcodeproj` (richiede sudo)
3. **Downgrade Xcode:** Non consigliato, ma alcuni utenti hanno risolto tornando a Xcode 15.x
4. **Attendi fix ufficiale:** Il problema è noto e verrà risolto in una futura versione di CocoaPods/xcodeproj

