# Struttura File di Build - Spiegazione

## Differenza tra `macos/` e `build/macos/`

### `macos/` - Codice Sorgente e Configurazione Progetto

**Posizione:** `$MYTEAM_REPO_ROOT/macos/`

**Contenuto:**
- **Progetto Xcode** (`Runner.xcodeproj/`, `Runner.xcworkspace/`)
- **Codice sorgente Swift** (`Runner/AppDelegate.swift`, `Runner/MainFlutterWindow.swift`)
- **Configurazioni** (`Runner/Configs/`, `Runner/Info.plist`)
- **Entitlements** (`Runner/Debug.entitlements`, `Runner/Release.entitlements`)
- **Assets** (`Runner/Assets.xcassets/`)
- **Dipendenze CocoaPods** (`Podfile`, `Podfile.lock`, `Pods/`)
- **File Flutter generati** (`Flutter/ephemeral/`)

**Caratteristiche:**
- ✅ **Fa parte del codice sorgente** (va nel repository Git)
- ✅ **Modificato manualmente** durante lo sviluppo
- ✅ **Versione controllata** (tracking Git)
- ✅ **Struttura fissa** definita da Flutter/Xcode

**Quando viene modificato:**
- Configurazione code signing
- Modifica entitlements
- Aggiunta dipendenze CocoaPods
- Modifica configurazioni Xcode

---

### `build/macos/` - Output di Build

**Posizione:** `$MYTEAM_REPO_ROOT/build/macos/`

**Contenuto:**
- **Framework compilati** (`FlutterMacOS.framework`, `App.framework`)
- **App compilata** (`myteam_video_app.app`)
- **File intermedi** (`Build/Intermediates.noindex/`)
- **File temporanei** generati durante la build

**Caratteristiche:**
- ❌ **NON fa parte del codice sorgente** (non va nel repository Git)
- ❌ **Generato automaticamente** da Flutter/Xcode
- ❌ **Può essere eliminato** senza problemi (può essere rigenerato)
- ✅ **Organizzato per piattaforma** automaticamente da Flutter

**Quando viene generato:**
- Durante `flutter build macos`
- Durante build in Xcode
- Durante `flutter run -d macos` (se macOS è abilitato)

**Struttura tipica:**
```
build/macos/
├── Build/
│   ├── Products/
│   │   └── Debug/
│   │       ├── myteam_video_app.app
│   │       ├── App.framework/
│   │       └── FlutterMacOS.framework/
│   └── Intermediates.noindex/
└── ...
```

---

## Organizzazione File di Build

### Flutter Organizza Automaticamente

Flutter organizza già automaticamente i file di build per piattaforma:

```
build/
├── macos/          # Output build macOS
├── ios/            # Output build iOS
├── android/        # Output build Android
├── windows/        # Output build Windows
└── linux/          # Output build Linux
```

**Non è necessario modificare questa struttura** - Flutter la gestisce automaticamente.

### Quando Pulire Build

Puoi eliminare `build/` quando:
- ✅ Vuoi liberare spazio disco
- ✅ Hai problemi di build
- ✅ Vuoi una build completamente pulita

**Comando:**
```bash
flutter clean
# Oppure manualmente:
rm -rf build/
```

---

## Gestione File di Build

### File da Ignorare (Git)

I file di build NON devono essere committati. Aggiungi a `.gitignore`:

```gitignore
# Build outputs
build/
*.app
*.framework
*.dSYM

# Flutter/Dart
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
```

### File da Committare

**macos/** contiene file che VANNO committati:
- ✅ `Runner.xcodeproj/` (progetto Xcode)
- ✅ `Runner/` (codice sorgente Swift)
- ✅ `Podfile`, `Podfile.lock` (dipendenze)
- ✅ `Runner/Configs/` (configurazioni)
- ✅ `Runner/*.entitlements` (entitlements)

**macos/** contiene file che NON vanno committati:
- ❌ `Pods/` (generato da CocoaPods)
- ❌ `Flutter/ephemeral/` (generato da Flutter)
- ❌ `Runner.xcworkspace/xcuserdata/` (preferenze utente)

---

## Best Practices

### 1. Non Modificare Manualmente `build/`
- I file in `build/` sono generati automaticamente
- Modificarli manualmente può causare problemi
- Usa `flutter clean` per pulire

### 2. Modifica Solo `macos/` per Configurazioni
- Per code signing: modifica `macos/Runner.xcodeproj/`
- Per entitlements: modifica `macos/Runner/*.entitlements`
- Per dipendenze: modifica `macos/Podfile`

### 3. Usa Flutter CLI per Build
- `flutter build macos` - genera output in `build/macos/`
- `flutter run -d macos` - genera output e esegue
- `flutter clean` - pulisce tutti gli output

### 4. Usa Xcode per Build macOS
- Apri `macos/Runner.xcworkspace` in Xcode
- Build genera output in `build/macos/`
- Non modificare `build/` manualmente

---

## Struttura Consigliata

### Codice Sorgente (Repository)
```
MyTeam/
├── macos/              # ✅ Codice sorgente macOS (Git)
│   ├── Runner.xcodeproj/
│   ├── Runner/
│   ├── Podfile
│   └── ...
├── ios/                # ✅ Codice sorgente iOS (Git)
│   └── ...
└── app/                # ✅ Codice Flutter (Git)
    └── ...
```

### Output Build (Ignorato da Git)
```
MyTeam/
├── build/              # ❌ Output build (ignorato da Git)
│   ├── macos/          # Output build macOS
│   ├── ios/            # Output build iOS
│   └── ...
└── ...
```

---

## Riepilogo

| Aspetto | `macos/` | `build/macos/` |
|---------|----------|----------------|
| **Tipo** | Codice sorgente | Output build |
| **Git** | ✅ Committato | ❌ Ignorato |
| **Modificato** | Manualmente | Automaticamente |
| **Eliminabile** | ❌ NO | ✅ Sì (può essere rigenerato) |
| **Dimensione** | ~1MB | Variabile (dipende da build) |
| **Quando usato** | Sempre | Solo durante build |

**Conclusione:** `macos/` è il progetto sorgente, `build/macos/` è l'output temporaneo. Non è necessario riorganizzare i file di build - Flutter li gestisce già automaticamente.

