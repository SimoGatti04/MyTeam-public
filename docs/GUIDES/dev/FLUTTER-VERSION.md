# Gestione Versione Flutter

## Versione Richiesta

**Flutter:** `3.38.1` (stable)  
**Dart:** `3.10.0` (incluso con Flutter 3.38.1)

## Verifica Versione

```bash
flutter --version
# Dovrebbe mostrare:
# Flutter 3.38.1 • channel stable
# Tools • Dart 3.10.0
```

## Gestione Versione con FVM (Raccomandato)

Per garantire che tutte le macchine (Windows, macOS, Android) usino la stessa versione di Flutter, usiamo **FVM (Flutter Version Management)**.

### Installazione FVM

**macOS/Linux:**
```bash
dart pub global activate fvm
```

**Windows:**
```bash
dart pub global activate fvm
# Aggiungi al PATH: %LOCALAPPDATA%\Pub\Cache\bin
```

### Setup Progetto

Il progetto include già un file `.fvmrc` con la versione Flutter richiesta:

```bash
# Installa la versione Flutter specificata
fvm install

# Usa la versione per questo progetto
fvm use 3.38.1
```

### Uso FVM

Dopo il setup, usa `fvm` prima di ogni comando Flutter:

```bash
# Invece di: flutter pub get
fvm flutter pub get

# Invece di: flutter build apk
fvm flutter build apk

# Invece di: flutter run
fvm flutter run
```

### Alias (Opzionale)

Per evitare di digitare `fvm` ogni volta, puoi creare un alias:

**macOS/Linux (.zshrc o .bashrc):**
```bash
alias flutter='fvm flutter'
alias dart='fvm dart'
```

**Windows (PowerShell):**
```powershell
Set-Alias flutter "fvm flutter"
Set-Alias dart "fvm dart"
```

## Senza FVM (Alternativa)

Se non vuoi usare FVM, assicurati di avere Flutter 3.38.1 installato globalmente:

```bash
# Verifica versione
flutter --version

# Se non è 3.38.1, aggiorna:
flutter upgrade
```

**Nota:** Senza FVM, devi assicurarti manualmente che tutte le macchine abbiano la stessa versione.

## CI/CD (GitHub Actions)

I workflow GitHub Actions sono configurati per usare Flutter 3.38.1. Vedi `.github/workflows/build.yml`.

## Troubleshooting

### Errore: "fvm: command not found"

Assicurati che FVM sia nel PATH:
```bash
# macOS/Linux
export PATH="$PATH":"$HOME/.pub-cache/bin"

# Windows
# Aggiungi %LOCALAPPDATA%\Pub\Cache\bin al PATH
```

### Errore: "Flutter version mismatch"

```bash
# Reinstalla la versione corretta
fvm install 3.38.1
fvm use 3.38.1
```

