# Documentazione Progetto MyTeam

## Entry point operativo

- Agenti e sviluppatori: [`../AGENTS.md`](../AGENTS.md)
- Procedura canonica, versionata e valida per ogni release di produzione: [`APP/PRODUCTION-RELEASE.md`](APP/PRODUCTION-RELEASE.md). Non pubblicare senza un GO esplicito separato dell'owner.
- Decisioni d'identità e sicurezza: [`APP/RELEASE-BASELINE.md`](APP/RELEASE-BASELINE.md)

## Modello Operativo e Roster Agenti

Le responsabilità di contribuzione sono riepilogate in **[ROSTER.md](ROSTER.md)**.

---

## Struttura Documentazione

Questa documentazione è organizzata in **3 sezioni principali**:

### 📖 Sezione Generale (`GENERAL/`)
**Documentazione comune tra server e app**
- Indice
- Requisiti (MoSCoW)
- Architettura client-server
- Modelli dati per comunicazione
- Struttura progetto generale

### 🔧 Sezione Server (`SERVER/`)
**Documentazione specifica server FastAPI**
- Indice
- Requisiti server (MoSCoW)
- Architettura server
- Modelli dati server (database, interni)
- Struttura progetto server
- **Guide per sviluppatori** (`GUIDES/dev/`)
- **Guide per utenti** (`GUIDES/user/`)

### 📱 Sezione App (`APP/`)
**Documentazione specifica app Flutter**
- Indice
- Requisiti app (MoSCoW)
- Architettura Flutter
- Modelli dati app (domain entities, local)
- Struttura progetto app
- **Guide per sviluppatori** (`GUIDES/dev/`)
- **Guide per utenti** (`GUIDES/user/`)

### 📋 Decisioni Tecniche
**File specifici per ogni decisione tecnica, organizzati per sezione:**
- **`GENERAL/DECISIONS/`** - Decisioni che riguardano comunicazione client-server (es: `compression.md`)
- **`SERVER/DECISIONS/`** - Decisioni specifiche server
- **`APP/DECISIONS/`** - Decisioni specifiche app

### 📚 Guide
**Guide centralizzate per sviluppatori e utenti:**
- **`GUIDES/dev/`** - Guide tecniche per sviluppatori (setup, build, troubleshooting, testing)
- **`GUIDES/user/`** - Guide utente (installazione, configurazione, utilizzo)

---

## Flusso di Lettura Consigliato

### 1. Inizio (Generale)
1. Leggere `GENERAL/INDEX.md`
2. Leggere `GENERAL/REQUIREMENTS.md`
3. Leggere `GENERAL/ARCHITECTURE.md`
4. Leggere `GENERAL/DATA-MODELS.md`

### 2. Server (Se sviluppi server)
1. Leggere `SERVER/INDEX.md`
2. Leggere `SERVER/REQUIREMENTS.md`
3. Leggere `SERVER/ARCHITECTURE.md`
4. Consultare `DECISIONS/` per decisioni specifiche
5. Consultare `GUIDES/dev/` per guide tecniche (testing, debugging)

### 3. App (Se sviluppi app)
1. Leggere `APP/INDEX.md`
2. Leggere `APP/REQUIREMENTS.md`
3. Leggere `APP/ARCHITECTURE.md`
4. Consultare `DECISIONS/` per decisioni specifiche
5. Consultare `GUIDES/dev/` per guide tecniche (setup, build, troubleshooting)

### 4. Guide
- **Per Sviluppatori**: Vedere `GUIDES/dev/` per tutte le guide tecniche
- **Per Utenti**: Vedere `GUIDES/user/` per tutte le guide utente

---

## Quick Start

### Server
```bash
cd server
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python -m uvicorn app.main:app --reload
```

### App (Future)
```bash
cd app
flutter pub get
flutter run
```

---

## Note

- **Compressione**: Client-side prima upload (480p-4K, 24-120fps) ✅
- **Transcoding**: Server-side future (opzionale) ❌
- **Autenticazione**: Nessuna (app privata, utente singolo)
- **Database**: SQLite (metadata, video su disco)

---

## Stato Progetto

- ✅ Documentazione completa e organizzata
- ✅ Architettura definita
- ✅ Server setup base completato
- 🔄 Implementazione in corso

---

