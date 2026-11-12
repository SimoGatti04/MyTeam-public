# GitHub Actions - Build Automatiche

## Panoramica

GitHub Actions permette di buildare automaticamente l'app per Windows, Android e macOS senza bisogno di avere tutte le piattaforme installate localmente. Questo è particolarmente utile se sviluppi su macOS e vuoi buildare per Windows.

## Vantaggi

✅ **Build cross-platform**: Builda per Windows anche se sei su macOS  
✅ **Automatico**: Builda automaticamente su push/PR  
✅ **Manuale**: Puoi triggerare build manualmente quando vuoi  
✅ **Artefatti**: Scarica i file buildati direttamente da GitHub  
✅ **Gratuito**: GitHub Actions offre 2000 minuti/mese gratuiti per account privati

## Setup

### 1. Verifica Workflow

Il workflow è già configurato in `.github/workflows/build.yml`. Non serve configurazione aggiuntiva.

### 2. Push su GitHub

Assicurati che il repository sia su GitHub:

```bash
git remote -v  # Verifica remote
git push origin main  # Push su GitHub
```

## Uso

### Build Manuale (Consigliato)

1. Vai su GitHub → **Actions** tab
2. Seleziona **Build Flutter App** workflow
3. Clicca **Run workflow**
4. Scegli:
   - **Piattaforma**: `windows`, `android`, `macos`, o `all`
   - **Tipo build**: `release` o `debug`
5. Clicca **Run workflow**

### Build Automatica

Il workflow si attiva automaticamente quando:
- Fai push su `main` o `master`
- Crei una Pull Request
- Modifichi file in `lib/`, `pubspec.yaml`, o il workflow stesso

## Download Artefatti

Dopo che il workflow completa:

1. Vai su **Actions** tab
2. Clicca sulla run completata
3. Scorri in basso fino a **Artifacts**
4. Clicca sul nome dell'artefatto (es: `windows-release`)
5. Scarica il file ZIP

### Contenuto Artefatti

#### Windows
- **Release**: `build/windows/x64/runner/Release/MyTeam.exe`
- **Debug**: `build/windows/x64/runner/Debug/MyTeam.exe`

#### Android
- **APK Release**: `app-release.apk`
- **APK Debug**: `app-debug.apk`
- **AAB Release**: `app-release.aab` (per Google Play)

#### macOS
- **Release**: `build/macos/Build/Products/Release/MyTeam.app`
- **Debug**: `build/macos/Build/Products/Debug/MyTeam.app`

## Workflow Configurazione

Il workflow supporta:

### Trigger
- **Manuale** (`workflow_dispatch`): Build quando vuoi
- **Push**: Build automatica su push a main/master
- **Pull Request**: Build automatica su PR

### Piattaforme
- ✅ **Windows** - Build su `windows-latest`
- ✅ **Android** - Build su `ubuntu-latest`
- ✅ **macOS** - Build su `macos-latest`

### Build Types
- **Release**: Build ottimizzata per produzione
- **Debug**: Build con simboli di debug

## Personalizzazione

### Modificare Flutter Version

Modifica `.github/workflows/build.yml`:

```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.24.0'  # Cambia versione qui
    channel: 'stable'
```

### Aggiungere Piattaforme

Per aggiungere altre piattaforme (es: Linux), aggiungi un nuovo job:

```yaml
build-linux:
  name: Build Linux
  runs-on: ubuntu-latest
  steps:
    # ... steps simili a Windows
```

### Modificare Trigger

Per cambiare quando il workflow si attiva:

```yaml
on:
  push:
    branches:
      - main
      - develop  # Aggiungi branch
    paths:
      - 'lib/**'
      # Aggiungi altri path
```

## Troubleshooting

### Workflow Non Si Attiva

**Causa:** Push su branch diverso da `main`/`master` o file modificati non nel path.

**Soluzione:**
- Usa build manuale (`workflow_dispatch`)
- Verifica che i file modificati siano in `lib/` o `pubspec.yaml`

### Build Fallisce

**Causa:** Errori nel codice o dipendenze mancanti.

**Soluzione:**
1. Controlla i log nella run di GitHub Actions
2. Verifica che `flutter analyze` passi localmente
3. Verifica che `flutter pub get` funzioni localmente

### Artefatti Non Disponibili

**Causa:** Build fallita o artefatti scaduti (30 giorni).

**Soluzione:**
- Rilancia il workflow
- Gli artefatti sono disponibili per 30 giorni

### Build Troppo Lenta

**Causa:** Cache non configurata o dipendenze non cached.

**Soluzione:**
- Il workflow usa già caching automatico di Flutter
- Le build successive sono più veloci grazie al cache

## Limitazioni

⚠️ **Code Signing**: 
- Windows: Non richiede code signing per esecuzione locale
- macOS: Richiede code signing per distribuzione (non configurato nel workflow)
- Android: Richiede keystore per release su Google Play (non configurato nel workflow)

⚠️ **Tempo Build**:
- Windows: ~5-10 minuti
- Android: ~10-15 minuti
- macOS: ~10-15 minuti

⚠️ **Limiti GitHub**:
- Account privati: 2000 minuti/mese gratuiti
- Account pubblici: Illimitati

## Best Practices

1. **Usa build manuale** per test rapidi
2. **Usa build automatica** per verificare che tutto funzioni dopo push
3. **Scarica artefatti** subito dopo build (scadono dopo 30 giorni)
4. **Verifica localmente** prima di pushare per evitare build fallite

## Esempi

### Build Solo Windows (Manuale)

1. GitHub → Actions → Build Flutter App
2. Run workflow
3. Piattaforma: `windows`
4. Tipo: `release`
5. Run workflow

### Build Tutte le Piattaforme (Manuale)

1. GitHub → Actions → Build Flutter App
2. Run workflow
3. Piattaforma: `all`
4. Tipo: `release`
5. Run workflow

### Build Automatica su Push

```bash
# Modifica codice
git add .
git commit -m "Fix: miglioramento upload"
git push origin main

# GitHub Actions builda automaticamente Windows
```

## Supporto

Per problemi:
- Controlla i log in GitHub Actions
- Vedi [BUILD-TROUBLESHOOTING.md](BUILD-TROUBLESHOOTING.md) per problemi comuni
- Verifica che Flutter version sia compatibile

