#!/bin/bash

# Script per build macOS con risoluzione automatica di problemi comuni
# Uso: ./scripts/build_macos.sh [--debug|--release]

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default: release
BUILD_MODE="${1:---release}"

echo -e "${GREEN}🚀 Build macOS - Risoluzione Problemi Automatica${NC}"
echo ""

# 1. Verifica Flutter
echo -e "${YELLOW}📋 Verifica Flutter...${NC}"
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter non trovato. Installa Flutter prima di continuare.${NC}"
    exit 1
fi

# 2. Verifica architettura
echo -e "${YELLOW}📋 Verifica architettura sistema...${NC}"
ARCH=$(uname -m)
echo "   Architettura: $ARCH"
if [ "$ARCH" != "arm64" ]; then
    echo -e "${YELLOW}⚠️  Sistema non è arm64. Alcune librerie potrebbero non funzionare.${NC}"
fi

# 3. Verifica Homebrew e librerie necessarie
echo -e "${YELLOW}📋 Verifica dipendenze Homebrew...${NC}"
if command -v brew &> /dev/null; then
    echo "   Homebrew trovato"
    
    # Verifica librerie necessarie per FFmpeg
    MISSING_LIBS=()
    for lib in zlib libiconv; do
        if ! brew list "$lib" &> /dev/null; then
            MISSING_LIBS+=("$lib")
        fi
    done
    
    if [ ${#MISSING_LIBS[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Librerie mancanti: ${MISSING_LIBS[*]}${NC}"
        echo "   Installazione librerie mancanti..."
        brew install "${MISSING_LIBS[@]}"
    else
        echo "   ✅ Tutte le librerie necessarie sono installate"
    fi
else
    echo -e "${YELLOW}⚠️  Homebrew non trovato. Alcune dipendenze potrebbero mancare.${NC}"
fi

# 4. Pulisci attributi estesi (xattr) che causano problemi di code signing
echo -e "${YELLOW}🧹 Pulizia attributi estesi...${NC}"
if [ -d "build/macos" ]; then
    find build/macos -type f -exec xattr -c {} \; 2>/dev/null || true
    find build/macos -type d -exec xattr -c {} \; 2>/dev/null || true
    echo "   ✅ Attributi estesi rimossi da build/macos"
fi

# 5. Pulisci attributi estesi da file sorgente (se presenti)
echo -e "${YELLOW}🧹 Verifica attributi estesi file sorgente...${NC}"
if [ -d "macos" ]; then
    # Rimuovi solo attributi problematici, non tutti
    find macos -name "*.app" -exec xattr -c {} \; 2>/dev/null || true
    echo "   ✅ Verifica completata"
fi

# 6. Flutter clean (opzionale, commentato per velocità)
# echo -e "${YELLOW}🧹 Flutter clean...${NC}"
# flutter clean

# 7. Flutter pub get
echo -e "${YELLOW}📦 Aggiornamento dipendenze Flutter...${NC}"
flutter pub get

# 8. CocoaPods install
echo -e "${YELLOW}📦 Installazione dipendenze CocoaPods...${NC}"
cd macos
if [ ! -f "Podfile.lock" ] || [ "Podfile" -nt "Podfile.lock" ]; then
    echo "   Aggiornamento CocoaPods..."
    pod install
else
    echo "   ✅ CocoaPods già aggiornato"
fi
cd ..

# 9. Verifica file ephemeral
echo -e "${YELLOW}📋 Verifica file Flutter ephemeral...${NC}"
EPHEMERAL_FILES=(
    "macos/Flutter/ephemeral/Flutter-Generated.xcconfig"
    "macos/Flutter/ephemeral/FlutterInputs.xcfilelist"
    "macos/Flutter/ephemeral/FlutterOutputs.xcfilelist"
)

MISSING_EPHEMERAL=()
for file in "${EPHEMERAL_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        MISSING_EPHEMERAL+=("$file")
    fi
done

if [ ${#MISSING_EPHEMERAL[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  File ephemeral mancanti. Generazione...${NC}"
    # Genera file ephemeral con un build parziale
    flutter build macos --debug 2>&1 | grep -v "CodeSign" || true
    echo "   ✅ File ephemeral generati"
else
    echo "   ✅ Tutti i file ephemeral sono presenti"
fi

# 10. Build con workaround per code signing
echo -e "${GREEN}🔨 Build macOS ($BUILD_MODE)...${NC}"
echo ""

# Workaround: disabilita temporaneamente code signing, builda, rimuovi attributi, poi firma manualmente
# Questo evita il problema "resource fork, Finder information, or similar detritus not allowed"
echo -e "${YELLOW}📝 Workaround: Disabilito code signing temporaneamente...${NC}"

# Disabilita code signing temporaneamente modificando project.pbxproj
sed -i.bak 's/CODE_SIGN_IDENTITY = ".*"/CODE_SIGN_IDENTITY = "-"/g' macos/Runner.xcodeproj/project.pbxproj
sed -i.bak 's/"CODE_SIGN_IDENTITY\[sdk=macosx\*\]" = ".*"/"CODE_SIGN_IDENTITY[sdk=macosx*]" = "-"/g' macos/Runner.xcodeproj/project.pbxproj

# Build senza code signing
if flutter build macos "$BUILD_MODE" 2>&1 | tee /tmp/flutter_build.log; then
    BUILD_SUCCESS=true
else
    BUILD_SUCCESS=false
fi

# Ripristina code signing originale
if [ -f "macos/Runner.xcodeproj/project.pbxproj.bak" ]; then
    mv macos/Runner.xcodeproj/project.pbxproj.bak macos/Runner.xcodeproj/project.pbxproj
    echo "   ✅ Code signing ripristinato"
fi

if [ "$BUILD_SUCCESS" = true ]; then
    echo ""
    echo -e "${GREEN}✅ Build completato con successo!${NC}"
    
    # 11. Post-build: pulizia attributi estesi e code signing manuale
    echo -e "${YELLOW}🧹 Pulizia attributi estesi e code signing...${NC}"
    APP_PATH="build/macos/Build/Products/Release/MyTeam.app"
    if [ "$BUILD_MODE" == "--debug" ]; then
        APP_PATH="build/macos/Build/Products/Debug/MyTeam.app"
    fi
    
    if [ -d "$APP_PATH" ]; then
        # Rimuovi attributi estesi
        xattr -cr "$APP_PATH" 2>/dev/null || true
        echo "   ✅ Attributi estesi rimossi"
        
        # Firma manualmente l'app (se code signing è necessario)
        # Usa "Sign to Run Locally" per sviluppo locale
        if command -v codesign &> /dev/null; then
            echo "   🔐 Code signing manuale..."
            codesign --force --deep --sign - "$APP_PATH" 2>&1 | grep -v "replacing existing" || true
            echo "   ✅ Code signing completato"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}🎉 Build macOS completato!${NC}"
    echo "   App: $APP_PATH"
    exit 0
else
    echo ""
    echo -e "${RED}❌ Build fallito!${NC}"
    echo ""
    echo "Possibili soluzioni:"
    echo "1. Verifica code signing in Xcode:"
    echo "   - Apri macos/Runner.xcworkspace"
    echo "   - Vai su Signing & Capabilities"
    echo "   - Seleziona 'Automatically manage signing'"
    echo ""
    echo "2. Pulisci completamente:"
    echo "   ./scripts/clean_build.sh"
    echo ""
    echo "3. Build in Xcode invece di Flutter CLI:"
    echo "   open macos/Runner.xcworkspace"
    echo "   Product > Build (⌘B)"
    exit 1
fi

