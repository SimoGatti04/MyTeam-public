# Eliminazione Video

## Panoramica

L'eliminazione video rimuove completamente un video dal server, inclusi file, metadati e tutte le associazioni.

---

## Comportamento

### Cosa viene eliminato

Quando un video viene eliminato, il sistema rimuove:

1. **File video** dal disco (`VIDEOS_PATH`)
2. **Thumbnail** se esiste (`THUMBNAILS_PATH`)
3. **Tutte le associazioni**:
   - `VideoPlayer` (associazioni con giocatori)
   - `VideoTrainingType` (associazioni con tipi allenamento)
   - `VideoTeam` (associazioni con squadre)
   - `Note` (tutte le note associate al video)
4. **Record dal database** (`Video`)

### Operazioni in cascata

Le associazioni vengono eliminate automaticamente grazie a:
- **Cascade delete** configurato nelle relazioni SQLAlchemy
- **Eliminazione esplicita** nel metodo `delete_video()` per garantire pulizia completa

### Gestione errori

- Se il file video non esiste, l'operazione continua (file potrebbe essere già stato eliminato manualmente)
- Se il thumbnail non esiste, l'operazione continua
- Se si verifica un errore durante l'eliminazione, viene eseguito rollback del database

---

## API Endpoint

### DELETE /api/videos/{video_id}

**Descrizione**: Elimina un video dal server.

**Parametri**:
- `video_id` (path): ID del video da eliminare

**Risposta**:
- `204 No Content` se eliminazione riuscita
- `404 Not Found` se video non trovato
- `500 Internal Server Error` se errore durante eliminazione

**Esempio**:
```bash
DELETE /api/videos/123e4567-e89b-12d3-a456-426614174000
```

---

## Implementazione Server

### VideoService.delete_video()

```python
def delete_video(self, video_id: str) -> None:
    """Elimina video dal server (file, thumbnail, associazioni, record DB)."""
    # 1. Elimina associazioni
    # 2. Elimina file video
    # 3. Elimina thumbnail
    # 4. Elimina record DB
```

### Route API

```python
@router.delete("/api/videos/{video_id}", status_code=204)
async def delete_video(video_id: str, db: Session = Depends(get_db)):
    """Elimina video dal server."""
    video_service = VideoService(db)
    video_service.delete_video(video_id)
    return None
```

---

## Implementazione Client

### VideoRemoteDataSource.deleteVideo()

```dart
Future<void> deleteVideo(String id) async {
  final response = await apiClient.dio.delete(
    '${ApiConstants.videos}/$id',
  );
  
  if (response.statusCode == 204) {
    return; // Success
  } else {
    throw Exception('Delete video failed: ${response.statusCode}');
  }
}
```

### UI

L'eliminazione video dovrebbe:
1. Mostrare un dialog di conferma prima di eliminare
2. Mostrare un indicatore di caricamento durante l'operazione
3. Mostrare un messaggio di successo/errore
4. Navigare alla lista video dopo eliminazione riuscita

**Esempio UI**:
```dart
// Pulsante elimina nel video detail screen
IconButton(
  icon: const Icon(Icons.delete, color: Colors.red),
  onPressed: () => _showDeleteConfirmation(context, video),
  tooltip: 'Delete video',
)

// Dialog di conferma
Future<void> _showDeleteConfirmation(BuildContext context, Video video) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Video'),
      content: Text('Are you sure you want to delete "${video.title}"? This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  
  if (confirmed == true) {
    await _deleteVideo(context, video);
  }
}
```

---

## Sicurezza

### Considerazioni

- **Nessuna autenticazione**: L'app è privata, quindi non è necessario autenticazione
- **Conferma utente**: L'UI dovrebbe sempre richiedere conferma prima di eliminare
- **Validazione**: Il server verifica che il video esista prima di tentare l'eliminazione

### Backup

**Raccomandazione**: Prima di eliminare un video, considerare:
- Il video potrebbe essere già stato incluso in un backup automatico
- Se necessario, implementare un sistema di "soft delete" (mark as deleted) invece di eliminazione permanente

---

## Note di Implementazione

### Performance

- L'eliminazione è un'operazione sincrona
- Per video molto grandi, l'eliminazione del file potrebbe richiedere alcuni secondi
- Considerare operazioni asincrone per video molto grandi (future)

### Logging

- L'eliminazione dovrebbe essere loggata per audit
- Loggare eventuali errori durante eliminazione file/thumbnail

### Testing

Test da implementare:
- Eliminazione video con file esistente
- Eliminazione video con file mancante (dovrebbe continuare)
- Eliminazione video con associazioni (dovrebbe eliminarle tutte)
- Eliminazione video inesistente (dovrebbe restituire 404)

---

## Riferimenti

- [Video Service](../../../server/app/services/video_service.py)
- [Video API Routes](../../../server/app/api/routes/videos.py)
- [Video Organization System](../../APP/video-organization-system.md)

