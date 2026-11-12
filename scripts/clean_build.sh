#!/bin/bash
# Script per pulire e ricostruire il progetto Flutter
# Risolve problemi comuni di build failure

# Non usare set -e per permettere continuazione anche con errori minori
# set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🧹 [Clean Build] Inizio pulizia progetto Flutter..."

# 1. Flutter clean
echo "📦 [Clean Build] Eseguo flutter clean..."
flutter clean

# 2. Rimuovi build directories (ma NON macos/Flutter/ephemeral)
echo "🗑️  [Clean Build] Rimuovo directory build..."
rm -rf build/
rm -rf .dart_tool/
rm -rf .flutter-plugins
rm -rf .flutter-plugins-dependencies
# IMPORTANTE: NON rimuovere macos/Flutter/ephemeral - viene rigenerato da flutter pub get

# 3. Pub get (genera file ephemeral per macOS)
echo "📥 [Clean Build] Eseguo flutter pub get..."
flutter pub get

# IMPORTANTE: flutter pub get genera i file ephemeral necessari per macOS
# Non rimuovere la directory ephemeral dopo pub get!

# 4. Per macOS: pulisci e reinstalla CocoaPods
if [ -d "macos" ]; then
    echo "🍎 [Clean Build] Pulizia CocoaPods per macOS..."
    cd macos
    rm -rf Pods/
    rm -rf Podfile.lock
    # NON rimuovere Flutter/ephemeral - contiene file generati da Flutter
    pod install --repo-update 2>&1 | grep -v "\[!\]" || true  # Ignora warning CocoaPods
    if [ $? -ne 0 ]; then
        echo "⚠️  CocoaPods macOS fallito, ma continuo..."
    fi
    cd ..
    
    # Verifica che i file ephemeral siano stati generati
    if [ ! -f "macos/Flutter/ephemeral/Flutter-Generated.xcconfig" ]; then
        echo "⚠️  File ephemeral non trovati, rigenero..."
        flutter pub get
    fi
fi

# iOS non supportato - saltato

# 6. Per Android: pulisci Gradle cache (opzionale, più aggressivo)
if [ -d "android" ]; then
    echo "🤖 [Clean Build] Pulizia Gradle per Android..."
    cd android
    if [ -f "./gradlew" ]; then
        ./gradlew clean 2>/dev/null || echo "⚠️  Gradle clean fallito (normale se non hai Android SDK configurato)"
    else
        echo "⚠️  Gradlew non trovato, salto pulizia Gradle"
    fi
    cd ..
fi

echo "✅ [Clean Build] Pulizia completata!"
echo ""
echo "Ora puoi eseguire:"
echo "  flutter build apk --release         # Android APK"
echo "  flutter build appbundle --release  # Android AAB"
echo "  flutter build macos --debug         # macOS Debug"
echo "  flutter build macos --release       # macOS Release"
echo "  flutter build windows --release     # Windows Release"

