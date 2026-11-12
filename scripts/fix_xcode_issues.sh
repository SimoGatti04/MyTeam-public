#!/bin/bash

# Script per risolvere problemi comuni di Xcode dopo modifiche al codice o aggiornamenti dipendenze
# Uso: ./scripts/fix_xcode_issues.sh

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔧 Fix problemi Xcode${NC}"
echo ""

# 1. Abilita macOS desktop temporaneamente
echo -e "${YELLOW}📱 Abilitazione macOS desktop...${NC}"
flutter config --enable-macos-desktop

# 2. Flutter clean (opzionale, commentato per velocità)
# echo -e "${YELLOW}🧹 Flutter clean...${NC}"
# flutter clean

# 3. Flutter pub get (genera file ephemeral)
echo -e "${YELLOW}📦 Aggiornamento dipendenze Flutter...${NC}"
flutter pub get

# 4. Verifica e genera file ephemeral se mancanti
echo -e "${YELLOW}📋 Verifica file Flutter ephemeral...${NC}"
EPHEMERAL_DIR="macos/Flutter/ephemeral"
EPHEMERAL_FILES=(
    "$EPHEMERAL_DIR/Flutter-Generated.xcconfig"
    "$EPHEMERAL_DIR/FlutterInputs.xcfilelist"
    "$EPHEMERAL_DIR/FlutterOutputs.xcfilelist"
)

# Crea directory se non esiste
mkdir -p "$EPHEMERAL_DIR"

MISSING_FILES=()
for file in "${EPHEMERAL_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        MISSING_FILES+=("$file")
    fi
done

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  File ephemeral mancanti. Generazione...${NC}"
    # Genera file ephemeral con un build parziale (ignora errori di code signing)
    flutter build macos --debug 2>&1 | grep -v "CodeSign" | grep -v "error:" || true
    echo "   ✅ File ephemeral generati"
else
    echo "   ✅ Tutti i file ephemeral sono presenti"
fi

# 5. Fix PrivacyInfo.xcprivacy per volume_controller
echo -e "${YELLOW}🔒 Fix PrivacyInfo.xcprivacy...${NC}"
# Cerca il file in tutte le versioni di volume_controller
PRIVACY_FILE=$(find "$HOME/.pub-cache/hosted/pub.dev" -name "PrivacyInfo.xcprivacy" -path "*/volume_controller*/macos/*" 2>/dev/null | head -1)

if [ -n "$PRIVACY_FILE" ] && [ -f "$PRIVACY_FILE" ]; then
    # Crea directory di destinazione
    DEST_DIR="macos/Runner/PrivacyInfo"
    mkdir -p "$DEST_DIR"
    
    # Copia il file come risorsa
    cp "$PRIVACY_FILE" "$DEST_DIR/PrivacyInfo.xcprivacy"
    echo "   ✅ PrivacyInfo.xcprivacy copiato da: $PRIVACY_FILE"
    echo "   ✅ Destinazione: $DEST_DIR/PrivacyInfo.xcprivacy"
    
    # Aggiungi al project.pbxproj se non presente (richiede modifica manuale in Xcode)
    echo "   ℹ️  Se vedi ancora l'errore, aggiungi manualmente in Xcode:"
    echo "      1. Apri macos/Runner.xcworkspace"
    echo "      2. Clicca destro su 'Runner' > 'Add Files to Runner...'"
    echo "      3. Seleziona macos/Runner/PrivacyInfo/PrivacyInfo.xcprivacy"
    echo "      4. Deseleziona 'Copy items if needed'"
    echo "      5. Seleziona 'Add to targets: Runner'"
    echo "      6. Verifica 'Target Membership' > 'Runner' nella tab File Inspector"
else
    echo "   ⚠️  File PrivacyInfo.xcprivacy non trovato"
    echo "   ℹ️  Potrebbe non essere necessario o il plugin è stato aggiornato"
    echo "   ℹ️  Se vedi l'errore, verifica manualmente in:"
    echo "      $HOME/.pub-cache/hosted/pub.dev/volume_controller-*/macos/"
fi

# 6. CocoaPods install
echo -e "${YELLOW}📦 Installazione dipendenze CocoaPods...${NC}"
cd macos
if [ ! -f "Podfile.lock" ] || [ "Podfile" -nt "Podfile.lock" ]; then
    echo "   Aggiornamento CocoaPods..."
    pod install
else
    echo "   ✅ CocoaPods già aggiornato"
fi
cd ..

# 7. Verifica file .xcfilelist di CocoaPods
echo -e "${YELLOW}📋 Verifica file CocoaPods .xcfilelist...${NC}"
PODS_XCFILELIST=(
    "macos/Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-Debug-input-files.xcfilelist"
    "macos/Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-Debug-output-files.xcfilelist"
    "macos/Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-Release-input-files.xcfilelist"
    "macos/Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-Release-output-files.xcfilelist"
)

MISSING_PODS_FILES=()
for file in "${PODS_XCFILELIST[@]}"; do
    if [ ! -f "$file" ]; then
        MISSING_PODS_FILES+=("$file")
    fi
done

if [ ${#MISSING_PODS_FILES[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  File CocoaPods .xcfilelist mancanti. Rigenerazione...${NC}"
    cd macos
    pod install --repo-update
    cd ..
    echo "   ✅ File CocoaPods .xcfilelist rigenerati"
else
    echo "   ✅ Tutti i file CocoaPods .xcfilelist sono presenti"
fi

# 8. Disabilita macOS desktop (opzionale)
echo -e "${YELLOW}📱 Disabilitazione macOS desktop...${NC}"
flutter config --no-enable-macos-desktop

# 9. Verifica FLUTTER_ROOT (se necessario)
echo -e "${YELLOW}🔍 Verifica configurazione Flutter...${NC}"
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}⚠️  Flutter non trovato nel PATH${NC}"
    echo "   Verifica che Flutter sia installato e nel PATH"
    echo "   Oppure usa FVM: fvm flutter --version"
else
    FLUTTER_VERSION=$(flutter --version | head -1)
    echo "   ✅ Flutter trovato: $FLUTTER_VERSION"
    
    # Verifica FLUTTER_ROOT
    if [ -z "$FLUTTER_ROOT" ]; then
        # Prova a trovare Flutter root
        FLUTTER_BIN=$(which flutter)
        if [ -n "$FLUTTER_BIN" ]; then
            FLUTTER_ROOT=$(dirname $(dirname "$FLUTTER_BIN"))
            echo "   ℹ️  FLUTTER_ROOT non impostato, trovato: $FLUTTER_ROOT"
            echo "   ℹ️  Se vedi errori 'macos_assemble.sh: No such file', imposta:"
            echo "      export FLUTTER_ROOT=\"$FLUTTER_ROOT\""
        fi
    else
        echo "   ✅ FLUTTER_ROOT: $FLUTTER_ROOT"
    fi
fi

echo ""
echo -e "${GREEN}✅ Fix completato!${NC}"
echo ""
echo "Prossimi passi:"
echo "1. Apri Xcode: open macos/Runner.xcworkspace"
echo "2. Se vedi ancora l'errore PrivacyInfo.xcprivacy:"
echo "   - Seleziona il file PrivacyInfo.xcprivacy in Xcode"
echo "   - Nella tab 'File Inspector', imposta 'Target Membership' su 'Runner'"
echo "3. Per il warning 'Run script build phase':"
echo "   - Vai su Build Phases > Run Script (embed)"
echo "   - Deseleziona 'Based on dependency analysis'"
echo "4. Se vedi 'PhaseScriptExecution failed':"
echo "   - Controlla quale script fallisce in Xcode Report Navigator (⌘9)"
echo "   - Se è Flutter Assemble, verifica FLUTTER_ROOT"
echo "   - Se è CocoaPods, esegui: cd macos && pod install && cd .."
echo "5. Premi ⌘R per buildare ed eseguire"

