# Personalizzazione Nome e Logo App (Tutte le Piattaforme)

Questa guida spiega come personalizzare nome e icona dell'app per tutte le piattaforme supportate (Android, macOS, Windows).

**Icone:** Configurazione unificata con `flutter_launcher_icons` - genera automaticamente tutte le dimensioni necessarie.

**Nome App:** Richiede aggiornamento manuale nei file di configurazione di ogni piattaforma (vedi sezione "Applicazione Nome App").

## Configurazione Unificata Icone

### Step 1: Installa flutter_launcher_icons

Aggiungi a `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  flutter_launcher_icons: ^0.13.1  # Aggiungi questo
```

### Step 2: Prepara la Tua Icona

1. Crea una cartella `assets/icon/` nella root del progetto
2. Aggiungi la tua icona:
   - Nome: `icon.png`
   - Dimensione: **1024x1024 px**
   - Formato: **PNG**
   - Sfondo: Trasparente o solido (consigliato trasparente)

### Step 3: Configura in pubspec.yaml

Aggiungi questa configurazione a `pubspec.yaml`:

```yaml
flutter:
  uses-material-design: true
  
  # Assets (se non già presente)
  assets:
    - assets/icon/

# Configurazione unificata nome e icona
flutter_launcher_icons:
  # Nome app (verrà applicato a tutte le piattaforme)
  app_name: "MyTeam Video"  # Cambia questo con il tuo nome
  
  # Icone per tutte le piattaforme
  android: true
  macos:
    generate: true
  windows:
    generate: true
  
  # Path alla tua icona
  image_path: "assets/icon/icon.png"
  
  # Adaptive Icons (Android 8.0+)
  adaptive_icon_background: "#FFFFFF"  # Colore sfondo
  adaptive_icon_foreground: "assets/icon/icon.png"  # Icona foreground
  
  # macOS specific (opzionale)
  macos_remove_alpha_icon: true
```

### Step 4: Genera Icone e Applica Nome

Esegui questi comandi:

```bash
# Installa dipendenze
flutter pub get

# Genera icone per tutte le piattaforme e applica nome
flutter pub run flutter_launcher_icons
```

Questo comando:
- ✅ Genera automaticamente tutte le dimensioni di icone necessarie per Android
- ✅ Genera icone per macOS
- ✅ Genera icone per Windows (se la cartella windows esiste)

**Nota:** Il nome dell'app (`app_name`) viene usato come riferimento, ma potrebbe essere necessario aggiornarlo manualmente nei file di configurazione di ogni piattaforma (vedi sezione "Verifica Configurazione" sotto).

## Applicazione Nome App (Manuale)

**Nota:** `flutter_launcher_icons` gestisce principalmente le icone. Per il nome dell'app, devi aggiornare manualmente i file di configurazione di ogni piattaforma.

### Android

Modifica `android/app/src/main/AndroidManifest.xml`:
```xml
<application
    android:label="MyTeam"  <!-- Cambia con il tuo nome -->
    android:icon="@mipmap/ic_launcher">
```

### macOS

Modifica `macos/Runner/Configs/AppInfo.xcconfig`:
```
PRODUCT_NAME = MyTeam  // Cambia con il tuo nome
```

**Suggerimento:** Crea uno script o usa un tool di sostituzione per aggiornare il nome su tutte le piattaforme contemporaneamente.

## Esempio Completo

### Struttura Progetto:

```
MyTeam/
├── assets/
│   └── icon/
│       └── icon.png  (1024x1024 px)
├── android/
├── macos/
├── windows/
├── pubspec.yaml
└── ...
```

### pubspec.yaml Completo:

```yaml
name: myteam_video_app
description: Self-hosted video management app for Android and Windows
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  # ... altre dipendenze ...

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  flutter_launcher_icons: ^0.13.1

flutter:
  uses-material-design: true
  
  assets:
    - assets/icon/

# Configurazione unificata
flutter_launcher_icons:
  app_name: "MyTeam Video"
  android: true
  macos: true
  windows: true
  image_path: "assets/icon/icon.png"
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/icon/icon.png"
```

## Comandi Rapidi

```bash
# Genera icone e applica nome (dopo modifiche)
flutter pub run flutter_launcher_icons

# Pulisci e rebuilda
flutter clean
flutter build apk --release  # Android
flutter build macos          # macOS
flutter build windows        # Windows
```

## Modifiche Future

Per cambiare nome o icona in futuro:

1. **Cambia nome**: Modifica `app_name` in `pubspec.yaml`
2. **Cambia icona**: Sostituisci `assets/icon/icon.png` con la nuova icona
3. **Rigenera**: `flutter pub run flutter_launcher_icons`
4. **Rebuilda**: `flutter clean && flutter build ...`

## Limitazioni

- **Nome app**: Alcune piattaforme potrebbero avere limiti di lunghezza
- **Icona**: Deve essere quadrata (1:1 ratio)
- **Formato**: Solo PNG per le icone
- **macOS**: Potrebbe richiedere configurazioni aggiuntive in Xcode per icone personalizzate avanzate

## Troubleshooting

### Icone non cambiano

1. Pulisci build: `flutter clean`
2. Rigenera icone: `flutter pub run flutter_launcher_icons`
3. Rimuovi app vecchia dal dispositivo
4. Rebuilda e reinstalla

### Nome non cambia su alcune piattaforme

1. Verifica che `flutter_launcher_icons` abbia generato correttamente
2. Controlla manualmente i file di configurazione (AndroidManifest.xml, Info.plist, etc.)
3. Se necessario, modifica manualmente i file specifici della piattaforma

### Errore durante generazione icone

1. Verifica che `assets/icon/icon.png` esista
2. Verifica che l'icona sia 1024x1024 px
3. Verifica che sia in formato PNG
4. Controlla i log per errori specifici

## Note Importanti

1. **Prima volta**: Esegui `flutter pub run flutter_launcher_icons` dopo ogni modifica a nome/icona
2. **Backup**: Fai backup delle icone originali se vuoi ripristinarle
3. **Versioning**: Aggiungi `assets/icon/` a Git, ma non le icone generate (sono già in .gitignore)
4. **CI/CD**: Includi `flutter pub run flutter_launcher_icons` nel processo di build se necessario

