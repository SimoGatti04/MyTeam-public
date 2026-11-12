# Documentazione App - Indice

## Panoramica

Questa sezione contiene documentazione **specifica dell'app** Flutter (client).

---

## Documenti

1. **[REQUIREMENTS.md](REQUIREMENTS.md)** - Requisiti app (MoSCoW)
2. **[ARCHITECTURE.md](ARCHITECTURE.md)** - Architettura Flutter (Clean Architecture)
3. **[DATA-MODELS.md](DATA-MODELS.md)** - Modelli dati app (domain entities, local models)
4. **[PROJECT-STRUCTURE.md](PROJECT-STRUCTURE.md)** - Struttura progetto app
5. **[video-organization-system.md](video-organization-system.md)** - Sistema di organizzazione video (ordinamento, filtri, tag, note)
6. **[OPTIMIZATION/android-windows-optimization.md](OPTIMIZATION/android-windows-optimization.md)** - Ottimizzazioni Android e Windows

## Release

- **[PRODUCTION-RELEASE.md](PRODUCTION-RELEASE.md)** — canonical fixed procedure for all future production releases, gate ledger, operator commands and agent routing.
  Release candidate producer/validator is plain Dart; artifact URLs are derived as `/updates/releases/<version>/<filename>` and must match the separately maintained release-validator contract.
- **[RELEASE-BASELINE.md](RELEASE-BASELINE.md)** — adopted production identity and security baseline; decision record, not an independent runbook.
- **[THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md)** — verified bundled package notices and unresolved native-binary distribution checks.
- **[RELEASE-CANDIDATE-RUNBOOK.md](RELEASE-CANDIDATE-RUNBOOK.md)** — historical first-candidate notes; superseded by `PRODUCTION-RELEASE.md` for execution.
- **[QA-UPDATER-BUILD.md](QA-UPDATER-BUILD.md)** — QA-only A/B artifacts; not production release material.

## Guide

Vedi [../GUIDES/](../GUIDES/) per tutte le guide:
- **Per Sviluppatori**: [GUIDES/dev/](../GUIDES/dev/) - Setup, build, troubleshooting
- **Per Utenti**: [GUIDES/user/](../GUIDES/user/) - Come usare l'applicazione

---

## Flusso di Lettura

### Per Sviluppatori

1. Leggere **REQUIREMENTS.md** per capire requisiti app
2. Leggere **ARCHITECTURE.md** per capire architettura Flutter
3. Leggere **DATA-MODELS.md** per capire modelli dati app
4. Leggere **PROJECT-STRUCTURE.md** per capire struttura app
5. Leggere le guide in [GUIDES/dev/](../GUIDES/dev/) per setup e build

### Per Utenti

1. Leggere le guide in [GUIDES/user/](../GUIDES/user/) per usare l'applicazione

---

## Build e Esecuzione

### Android
- Usa Flutter CLI: `flutter run -d <device-id>`
- Vedi [GUIDES/dev/QUICK-START.md](../GUIDES/dev/QUICK-START.md) per dettagli

### macOS
- Usa Xcode direttamente (non Flutter CLI)
- Vedi [GUIDES/dev/XCODE-BUILD.md](../GUIDES/dev/XCODE-BUILD.md) per istruzioni dettagliate

### Windows
- Usa Flutter CLI: `flutter run -d windows`
- Vedi [GUIDES/dev/WINDOWS-BUILD.md](../GUIDES/dev/WINDOWS-BUILD.md) per istruzioni dettagliate

---

Per decisioni tecniche implementazione:
- **Generali** (client-server): Vedere `GENERAL/DECISIONS/` (es: `compression.md`)
- **App**: Vedere `APP/DECISIONS/`

