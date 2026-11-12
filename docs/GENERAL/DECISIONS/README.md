# Decisioni Tecniche Generali

## Panoramica

Questa cartella contiene **decisioni tecniche finali che riguardano la comunicazione tra server e app** o aspetti comuni.

---

## File Disponibili

### [COMPRESSION.md](COMPRESSION.md)
**Compressione Video Client-Side**
- Implementazione client (Flutter)
- Risoluzioni e framerate supportati
- Packages necessari

### [upload.md](upload.md)
**Upload Video**
- Flusso completo client-server
- Implementazione client-side
- Implementazione server-side
- Packages necessari

### [error-handling.md](error-handling.md)
**Error Handling e Retry Logic**
- Strategia retry
- Implementazione client-side
- Implementazione server-side
- Error logging

### [file-limits.md](file-limits.md)
**Limiti File Size e Upload Queue**
- Limiti configurati
- Configurazione
- Implementazioni
- Hardware raccomandato

### [file-validation.md](file-validation.md)
**File Validation**
- Filename sanitization
- Path traversal protection
- Implementazione client-side
- Implementazione server-side

---

## Quando Creare File Qui

✅ **Crea file qui se:**
- Decisione riguarda comunicazione client-server
- Decisione riguarda entrambi (server e app)
- Decisione riguarda API/contratti di comunicazione
- Decisione riguarda formati dati condivisi

❌ **NON creare file qui se:**
- Decisione riguarda solo server → `SERVER/DECISIONS/`
- Decisione riguarda solo app → `APP/DECISIONS/`

---

Per decisioni specifiche:
- **Server**: Vedere `SERVER/DECISIONS/`
- **App**: Vedere `APP/DECISIONS/`
