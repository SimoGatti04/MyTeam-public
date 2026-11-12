#!/bin/bash
# Script per creare i file XCFileList mancanti per macOS build

set -e

cd "$(dirname "$0")/.."

echo "🔧 Creazione file XCFileList mancanti..."

# Crea directory se non esiste
mkdir -p "macos/Pods/Target Support Files/Pods-Runner"
mkdir -p "macos/Pods/Target Support Files/Pods-RunnerTests"
mkdir -p "macos/Flutter/ephemeral"

# Crea file XCFileList vuoti (CocoaPods li popolerà quando funzionerà)
touch "macos/Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-Debug-input-files.xcfilelist"
touch "macos/Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-Debug-output-files.xcfilelist"
touch "macos/Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-Release-input-files.xcfilelist"
touch "macos/Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-Release-output-files.xcfilelist"

touch "macos/Flutter/ephemeral/FlutterInputs.xcfilelist"
touch "macos/Flutter/ephemeral/FlutterOutputs.xcfilelist"

echo "✅ File XCFileList creati!"
echo ""
echo "⚠️  Nota: Questi file sono vuoti. Per una build completa, devi:"
echo "   1. Risolvere il problema CocoaPods (vedi README_MACOS_BUILD.md)"
echo "   2. Oppure usare Xcode direttamente per la build"
echo ""
echo "Per buildare in Xcode:"
echo "   open macos/Runner.xcworkspace"

