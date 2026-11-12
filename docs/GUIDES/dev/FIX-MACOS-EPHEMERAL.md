# Fix macOS Ephemeral Files Error

## Problema

Errore durante build macOS:
```
error: could not find included file 'ephemeral/Flutter-Generated.xcconfig' in search paths
error: Unable to load contents of file list: 'ephemeral/FlutterInputs.xcfilelist'
error: Unable to load contents of file list: 'ephemeral/FlutterOutputs.xcfilelist'
```

## Causa

I file nella directory `macos/Flutter/ephemeral/` sono stati rimossi o non sono stati generati. Questi file vengono generati automaticamente da Flutter quando si esegue `flutter pub get`.

## Soluzione Rapida

```bash
# Rigenera file ephemeral
flutter pub get

# Verifica che i file siano stati generati
ls -la macos/Flutter/ephemeral/
```

Dovresti vedere:
- `Flutter-Generated.xcconfig`
- `FlutterInputs.xcfilelist`
- `FlutterOutputs.xcfilelist`

## Soluzione Completa

Se il problema persiste:

```bash
# 1. Pulisci progetto
flutter clean

# 2. Rigenera dipendenze (genera file ephemeral)
flutter pub get

# 3. Reinstalla CocoaPods
cd macos
pod install
cd ..

# 4. Verifica file ephemeral
ls -la macos/Flutter/ephemeral/
```

## Prevenzione

**IMPORTANTE:** Non rimuovere manualmente la directory `macos/Flutter/ephemeral/`. Questi file vengono generati automaticamente da Flutter e sono necessari per la build.

Lo script `clean_build.sh` è stato aggiornato per:
- ✅ NON rimuovere `macos/Flutter/ephemeral/`
- ✅ Verificare che i file siano presenti dopo `flutter pub get`
- ✅ Rigenerarli automaticamente se mancanti

## Verifica

Dopo `flutter pub get`, verifica che esistano:

```bash
test -f macos/Flutter/ephemeral/Flutter-Generated.xcconfig && echo "✅ OK" || echo "❌ Mancante"
test -f macos/Flutter/ephemeral/FlutterInputs.xcfilelist && echo "✅ OK" || echo "❌ Mancante"
test -f macos/Flutter/ephemeral/FlutterOutputs.xcfilelist && echo "✅ OK" || echo "❌ Mancante"
```

## Note

- I file `ephemeral` vengono generati da Flutter automaticamente
- Non devono essere committati in Git (sono già in `.gitignore`)
- Se mancano, esegui sempre `flutter pub get` prima di buildare

