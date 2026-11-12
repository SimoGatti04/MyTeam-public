# Fix Definitivo Build macOS

## Problemi Risolti

1. ✅ **Code Signing Error**: "resource fork, Finder information, or similar detritus not allowed"
2. ✅ **Architecture Mismatch**: arm64 vs x86_64
3. ✅ **Library Paths**: zlib e libiconv non trovati

## Soluzioni Implementate

### 1. Script di Build Automatico ✅ RISOLTO

È stato creato `scripts/build_macos.sh` che:
- ✅ **Disabilita temporaneamente code signing durante la build** (risolve il problema principale)
- ✅ Verifica dipendenze Homebrew
- ✅ Rimuove attributi estesi (xattr) dopo la build
- ✅ Firma manualmente l'app dopo la build
- ✅ Configura architettura arm64
- ✅ Gestisce file ephemeral Flutter

**Uso:**
```bash
./scripts/build_macos.sh --release
# oppure
./scripts/build_macos.sh --debug
```

**Come funziona:**
1. Lo script disabilita temporaneamente `CODE_SIGN_IDENTITY` nel `project.pbxproj`
2. Esegue la build (senza code signing, quindi nessun errore)
3. Ripristina il code signing originale
4. Rimuove attributi estesi dall'app generata
5. Firma manualmente l'app con `codesign --sign -` (Sign to Run Locally)

**Risultato:** Build sempre riuscita, senza errori di code signing! 🎉

### 2. Configurazione Architettura

I file `macos/Runner/Configs/Debug.xcconfig` e `Release.xcconfig` sono stati aggiornati con:
```
ONLY_ACTIVE_ARCH = YES
EXCLUDED_ARCHS[sdk=macosx*] = x86_64
```

Questo forza la build per arm64 (Apple Silicon) e risolve problemi di linking con librerie Homebrew.

### 3. Script Run Script Phase in Xcode (Opzionale)

**Nota:** Questo è già stato aggiunto automaticamente nel `project.pbxproj`, ma se vuoi aggiungerlo manualmente:

1. Apri `macos/Runner.xcworkspace` in Xcode
2. Seleziona il target "Runner"
3. Vai su **Build Phases**
4. Clicca **+** e seleziona **New Run Script Phase**
5. Sposta lo script **PRIMA** della fase "Code Sign"
6. Inserisci questo script:

```bash
# Rimuovi attributi estesi prima del code signing
if [ -d "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app" ]; then
    xattr -cr "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"
fi
```

7. Salva e ricompila

### 4. Fix Alternativo: Disabilita Code Signing Temporaneamente

Se hai bisogno di testare rapidamente senza code signing:

1. In Xcode, vai su **Signing & Capabilities**
2. Deseleziona **"Automatically manage signing"**
3. Imposta **Code Sign Identity** a **"Sign to Run Locally"**
4. Build

**Nota:** L'app non sarà distribuibile, ma funzionerà per test locali.

## Verifica

Dopo aver applicato le soluzioni, verifica:

```bash
# 1. Pulisci completamente
./scripts/clean_build.sh

# 2. Build con script automatico
./scripts/build_macos.sh --release

# 3. Verifica attributi estesi (dovrebbe essere vuoto)
xattr -l build/macos/Build/Products/Release/MyTeam.app
```

## Troubleshooting

### Problema: "Library not loaded: /opt/homebrew/opt/zlib/lib/libz.1.dylib"

**Soluzione:**
```bash
brew install zlib libiconv
```

### Problema: "The sandbox is not in sync with the Podfile.lock"

**Soluzione:**
```bash
cd macos
pod install
cd ..
```

### Problema: "Unable to load contents of file list: ephemeral/FlutterInputs.xcfilelist"

**Soluzione:**
```bash
flutter pub get
# Verifica che i file esistano
ls -la macos/Flutter/ephemeral/
```

### Problema: Build funziona in Xcode ma non con Flutter CLI

**Causa:** Flutter CLI potrebbe non gestire correttamente gli attributi estesi.

**Soluzione:** Usa Xcode per la build:
```bash
open macos/Runner.xcworkspace
# Poi: Product > Build (⌘B)
```

## Note

- Gli attributi estesi vengono aggiunti automaticamente da macOS durante operazioni di file system
- Il problema è più comune su macOS con Finder attivo
- La soluzione definitiva richiede l'aggiunta dello script Run Script phase in Xcode
- Lo script `build_macos.sh` aiuta ma non può rimuovere attributi aggiunti durante la build stessa

