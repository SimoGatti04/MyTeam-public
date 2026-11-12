# Video List - Server Implementation

> **Stato decisione:** comportamento non distruttivo corrente, introdotto dal commit B1
> `aba2ed4977d437c20b491c009f1f9e633487856a` (parent `d7d1590284aabcda433bea1f0f0bb785638b2694`).
> Lo storico della pulizia automatica riportato sotto è **SUPERSEDED** e non descrive il codice corrente.

## Endpoint GET /api/videos

### Funzionalità

- **Paginazione**: `page` (default: 1), `limit` (default: 20, max: 100)
- **Ricerca**: `search` (cerca in title/filename/players/training_types/teams/years)
- **Sorting**: `sort` (date_asc, date_desc, name_asc, name_desc, size_asc, size_desc, ecc.)
- **Filtri avanzati**: data (from/to, month, year), entità (player_ids, training_type_ids, team_ids), status

### Comportamento Non Distruttivo (Read-Only)

**Implementazione:**
- L'endpoint di lettura `GET /api/videos` opera esclusivamente come query idempotente di consultazione.
- **Nessuna cancellazione né mutazione SQL** viene eseguita a runtime durante l'interrogazione dell'elenco video.
- I record a database rimangono integri e visibili anche se:
  - Il file video su disco o storage condiviso è temporaneamente non disponibile (es. mount di rete/NFS/CSI temporaneamente disconnesso, riavvio storage).
  - Il file video non è ancora sincronizzato o presente.
  - Il campo `file_path` è vuoto o non impostato.
- Il conteggio `total` e la paginazione sono calcolati direttamente dalla query filtrata sul database (`query.count()`), garantendo coerenza matematica tra le varie pagine senza dipendere dallo stato contingente del filesystem.

**Motivazione:**
- Evita perdite catastrofiche di metadati e record a seguito di disconnessioni di storage temporanee o disallineamenti di mount.
- Rispetta il principio di responsabilità dei metodi HTTP (GET deve essere privo di effetti collaterali distruttivi).
- L'eliminazione dei record deve avvenire esclusivamente tramite invocazione esplicita degli endpoint dedicati di cancellazione (`DELETE /api/videos/{video_id}`) o script di manutenzione controllati con permessi espliciti.

### Comportamento precedente — SUPERSEDED

Prima di B1, `GET /api/videos` controllava l'esistenza dei file e chiamava `db.delete(video)` seguito da `db.commit()` quando il file mancava (o il percorso era vuoto). Questa pulizia implicita è **SUPERSEDED** dal commit B1 sopra: non va reintrodotta. Un file non disponibile non prova che il record sia orfano; può indicare un mount/storage temporaneamente assente.

### Evidenza e provenienza del rilascio

- Nel repository, B1 è un commit figlio diretto di `d7d1590284aabcda433bea1f0f0bb785638b2694` e modifica l'endpoint, questo documento e i test di isolamento. I test verificano record/file mancanti e assenza di SQL `INSERT`/`UPDATE`/`DELETE` durante il GET.
- Release gate: `server/tests/test_video_list_api_isolation.py::TestVideoListApiIsolation::test_list_endpoint_has_no_database_mutator_calls` vieta `db.delete`, `db.commit` e `db.flush` nell'handler; i test comportamentali dello stesso file verificano inoltre la conservazione dei record e nessuna mutazione SQL. Riferimento implementativo: B1 `aba2ed4977d437c20b491c009f1f9e633487856a`.
- La presenza del fix nel codice sorgente è tracciabile al commit B1 sopra; questo documento non attesta quale immagine sia attualmente in esecuzione. La provenienza e lo stato del runtime devono essere verificati separatamente dal proprietario del deployment prima di un cutover; qui non sono incluse procedure di accesso all'infrastruttura.

---

## Endpoint GET /api/videos/{video_id}

### Funzionalità

- Restituisce dettagli completi del video
- Include metadata, compression info, transcoding status

---

## Endpoint GET /api/videos/{video_id}/thumbnail

### Funzionalità

- Restituisce thumbnail del video
- Content-Type: image/jpeg
- Fallback a thumbnail di default se non disponibile
