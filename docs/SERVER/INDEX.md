# Documentazione Server - Indice

## Panoramica

Questa sezione contiene documentazione **specifica del server** FastAPI.

---

## Documenti

1. **[REQUIREMENTS.md](REQUIREMENTS.md)** - Requisiti server (MoSCoW)
2. **[ARCHITECTURE.md](ARCHITECTURE.md)** - Architettura server FastAPI
3. **[DATA-MODELS.md](DATA-MODELS.md)** - Modelli dati server (database, interni)
4. **[PROJECT-STRUCTURE.md](PROJECT-STRUCTURE.md)** - Struttura progetto server
5. **[TEST.md](TEST.md)** - Suite di test e risultati

## Guide

- [Server setup](../../server/README.md) - local development and configuration
- [Self-hosting](../../server/DEPLOY.md) - portable Docker Compose deployment

Vedi [../GUIDES/](../GUIDES/) per tutte le guide:
- **Per Sviluppatori**: [GUIDES/dev/](../GUIDES/dev/) - Testing, debugging
- **Per Utenti**: [GUIDES/user/](../GUIDES/user/) - Installazione, configurazione, utilizzo

---

## Flusso di Lettura

### Per Sviluppatori

1. Leggere **REQUIREMENTS.md** per capire requisiti server
2. Leggere **ARCHITECTURE.md** per capire architettura server
3. Leggere **DATA-MODELS.md** per capire modelli dati server
4. Leggere **PROJECT-STRUCTURE.md** per capire struttura server
5. Leggere le guide in [GUIDES/dev/](../GUIDES/dev/) per testing e debugging

### Per Utenti

1. Leggere le guide in [GUIDES/user/](../GUIDES/user/) per installare e configurare il server

---

Per decisioni tecniche implementazione:
- **Generali** (client-server): Vedere `GENERAL/DECISIONS/` (es: `compression.md`)
- **Server**: Vedere `SERVER/DECISIONS/`

