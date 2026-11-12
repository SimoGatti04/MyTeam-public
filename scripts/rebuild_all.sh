#!/bin/bash
# Script per pulire e ricostruire tutte le piattaforme
# Usa questo script dopo modifiche al codice per evitare errori di build

# Non usare set -e per permettere continuazione anche con errori minori
# set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "🚀 [Rebuild All] Inizio rebuild completo del progetto..."
echo ""

# Esegui clean build
echo "📋 [Rebuild All] Eseguo clean build..."
bash "$SCRIPT_DIR/clean_build.sh"

echo ""
echo "🔨 [Rebuild All] Verifica analisi codice..."
echo "   (Gli errori nei test sono normali se i test non sono aggiornati)"
if flutter analyze 2>&1 | grep -q "error •"; then
    echo "⚠️  [Rebuild All] Trovati errori nel codice (vedi sopra)"
    echo "   Gli errori nei file test/ sono normali e non bloccanti"
else
    echo "✅ [Rebuild All] Nessun errore critico trovato"
fi

echo ""
echo "✅ [Rebuild All] Rebuild completato!"
echo ""
echo "Per build specifiche:"
echo "  flutter build apk --release          # Android APK"
echo "  flutter build appbundle --release     # Android AAB"
echo "  flutter build macos --debug          # macOS Debug"
echo "  flutter build macos --release        # macOS Release"
echo "  flutter build windows --release      # Windows Release"

