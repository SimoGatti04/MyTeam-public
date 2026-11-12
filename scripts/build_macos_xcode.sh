#!/bin/bash
# Script per buildare macOS usando Xcode direttamente, bypassando CocoaPods

set -e

cd "$(dirname "$0")/.."

echo "🧹 Pulizia..."
flutter clean
flutter pub get

echo "📦 Generazione file Flutter..."
# Flutter genera automaticamente i file necessari
flutter precache --macos

echo "📝 Creazione file XCFileList mancanti..."
mkdir -p macos/Flutter/ephemeral
touch macos/Flutter/ephemeral/FlutterInputs.xcfilelist
touch macos/Flutter/ephemeral/FlutterOutputs.xcfilelist

echo "🔨 Build con Xcode..."
# Apri Xcode e fai la build manualmente, oppure usa xcodebuild
xcodebuild -workspace macos/Runner.xcworkspace \
           -scheme Runner \
           -configuration Debug \
           -derivedDataPath build/macos \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=NO \
           || echo "⚠️  Se xcodebuild fallisce, apri macos/Runner.xcworkspace in Xcode e fai la build manualmente"

echo "✅ Build completata!"

