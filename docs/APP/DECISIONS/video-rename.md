# Decisione: Rename Video Feature

**Data:** 2025-01-15  
**Stato:** ✅ Implementato

---

## Panoramica

Implementazione della feature per rinominare video, sia prima dell'upload che dopo l'upload.

---

## Requisiti

### 1. Rename Prima Upload
- Permettere all'utente di modificare il titolo del video prima di caricarlo
- Campo editabile nella schermata upload
- Pre-compilare con il nome del file selezionato (come default)
- Il titolo modificato viene usato durante l'upload

### 2. Rename Dopo Upload
- Permettere all'utente di modificare il titolo dei video già caricati
- Accessibile dalla VideoDetailScreen
- Aggiornamento immediato nel database e nella UI

---

## Architettura

### Clean Architecture

#### Domain Layer
- **Entity:** `Video` (già esistente, campo `title` già presente)
- **Use Case:** `UpdateVideoTitleUseCase` (nuovo)
- **Repository Interface:** `VideoRepository` (aggiungere metodo `updateVideoTitle`)

#### Data Layer
- **Repository Implementation:** `VideoRepositoryImpl` (aggiungere implementazione)
- **Remote Data Source:** `VideoRemoteDataSource` (aggiungere metodo `updateVideoTitle`)
- **Model:** `VideoResponse` (già esistente, supporta update)

#### Presentation Layer
- **Screen:** `UploadScreen` (modificare - aggiungere campo editabile)
- **Screen:** `VideoDetailScreen` (modificare - aggiungere UI per edit)
- **ViewModel:** `VideoDetailViewModel` (aggiungere metodo `updateTitle`)

---

## Implementazione Server

### Endpoint

**PUT /api/videos/{video_id}**

```python
@router.put("/api/videos/{video_id}", response_model=VideoResponse)
async def update_video(
    video_id: str,
    title: str = Form(...),
    db: Session = Depends(get_db),
):
    """Aggiorna titolo video.
    
    Args:
        video_id: ID video da aggiornare
        title: Nuovo titolo
        db: Database session
        
    Returns:
        VideoResponse: Video aggiornato
        
    Raises:
        HTTPException: 404 se video non trovato
        HTTPException: 400 se titolo vuoto o invalido
    """
```

### Service Method

**VideoService.update_video_title()**

```python
def update_video_title(self, video_id: str, title: str) -> Video:
    """Aggiorna titolo video.
    
    Args:
        video_id: ID video
        title: Nuovo titolo
        
    Returns:
        Video aggiornato
    """
```

### Validazione

- Titolo non vuoto (min 1 carattere, max 255 caratteri)
- Sanitizzazione caratteri speciali (opzionale)
- Verifica che il video esista

---

## Implementazione Client

### 1. Rename Prima Upload

#### UploadScreen Modifiche

**Aggiungere:**
- `TextEditingController _titleController`
- `TextFormField` per editare il titolo
- Pre-compilare con filename quando viene selezionato un file
- Usare `_titleController.text` invece di `videoName` durante upload

**Posizionamento UI:**
- Dopo la selezione del file
- Prima delle compression settings
- Label: "Video Title" o "Nome Video"

### 2. Rename Dopo Upload

#### Domain Layer

**UpdateVideoTitleUseCase:**
```dart
class UpdateVideoTitleUseCase {
  final VideoRepository repository;
  
  UpdateVideoTitleUseCase(this.repository);
  
  Future<Video> execute({
    required String videoId,
    required String newTitle,
  }) async {
    return await repository.updateVideoTitle(
      videoId: videoId,
      newTitle: newTitle,
    );
  }
}
```

#### Data Layer

**VideoRepository.updateVideoTitle():**
```dart
Future<Video> updateVideoTitle({
  required String videoId,
  required String newTitle,
}) async {
  final response = await remoteDataSource.updateVideoTitle(
    videoId: videoId,
    newTitle: newTitle,
  );
  return response.toEntity();
}
```

**VideoRemoteDataSource.updateVideoTitle():**
```dart
Future<VideoResponse> updateVideoTitle({
  required String videoId,
  required String newTitle,
}) async {
  final formData = FormData.fromMap({
    'title': newTitle,
  });
  
  final response = await apiClient.dio.put(
    '${ApiConstants.videos}/$videoId',
    data: formData,
  );
  
  return VideoResponse.fromJson(response.data);
}
```

#### Presentation Layer

**VideoDetailScreen Modifiche:**

**Aggiungere:**
- Icona edit accanto al titolo
- Dialog per editare il titolo
- Validazione titolo (non vuoto, max 255 caratteri)
- Loading state durante update
- Error handling

**UI Pattern:**
- Titolo cliccabile o icona edit
- Dialog con TextField pre-compilato
- Pulsanti "Annulla" e "Salva"
- SnackBar per feedback successo/errore

---

## Flusso Utente

### Rename Prima Upload

1. Utente seleziona video
2. Campo "Video Title" appare con nome file pre-compilato
3. Utente modifica il titolo (opzionale)
4. Utente clicca "Upload Video"
5. Il titolo modificato viene usato per l'upload

### Rename Dopo Upload

1. Utente naviga a VideoDetailScreen
2. Utente clicca icona edit accanto al titolo
3. Dialog appare con TextField pre-compilato con titolo corrente
4. Utente modifica il titolo
5. Utente clicca "Salva"
6. Loading indicator durante update
7. SnackBar conferma successo
8. UI aggiornata con nuovo titolo

---

## Validazione

### Client-Side
- Titolo non vuoto (trim whitespace)
- Max 255 caratteri
- Caratteri speciali permessi (per ora)

### Server-Side
- Titolo non vuoto
- Max 255 caratteri (database constraint)
- Verifica video esiste
- Sanitizzazione caratteri pericolosi (opzionale)

---

## Error Handling

### Client
- Network errors: Mostra messaggio user-friendly
- Validation errors: Mostra messaggio specifico
- Server errors: Mostra messaggio generico con dettagli in debug

### Server
- 404: Video non trovato
- 400: Titolo invalido (vuoto o troppo lungo)
- 500: Errore database

---

## Testing

### Manual Testing

**Rename Prima Upload:**
1. Seleziona video
2. Verifica campo titolo pre-compilato
3. Modifica titolo
4. Upload video
5. Verifica che il titolo modificato sia salvato

**Rename Dopo Upload:**
1. Apri VideoDetailScreen
2. Clicca icona edit
3. Modifica titolo
4. Salva
5. Verifica che il titolo sia aggiornato
6. Ricarica lista video
7. Verifica che il nuovo titolo sia visibile

### Edge Cases
- Titolo vuoto (dovrebbe essere validato)
- Titolo molto lungo (dovrebbe essere troncato o validato)
- Caratteri speciali nel titolo
- Update durante connessione instabile
- Video eliminato durante update

---

## Note Implementazione

1. **Backward Compatibility:** I video esistenti continuano a funzionare
2. **Default Title:** Se l'utente non modifica il titolo, usa il filename (comportamento attuale)
3. **UI Feedback:** Sempre mostrare feedback visivo (loading, success, error)
4. **Optimistic Update:** Considerare update ottimistico in futuro (aggiorna UI prima della risposta server)

---

## File da Modificare/Creare

### Server
- `server/app/api/routes/videos.py` - Aggiungere endpoint PUT
- `server/app/services/video_service.py` - Aggiungere metodo `update_video_title`

### Client - Domain
- `lib/domain/usecases/update_video_title_usecase.dart` (nuovo)
- `lib/domain/repositories/video_repository.dart` (modificare - aggiungere metodo)

### Client - Data
- `lib/data/repositories/video_repository_impl.dart` (modificare)
- `lib/data/datasources/remote/video_remote_datasource.dart` (modificare)

### Client - Presentation
- `lib/presentation/screens/upload/upload_screen.dart` (modificare - aggiungere campo titolo)
- `lib/presentation/screens/video/video_detail_screen.dart` (modificare - aggiungere UI edit)
- `lib/features/video/viewmodels/video_detail_viewmodel.dart` (modificare - aggiungere metodo update)

---

## Riferimenti

- **Architettura:** `docs/GENERAL/ARCHITECTURE.md`
- **Video Detail Screen:** `docs/APP/DECISIONS/video-detail-screen.md`
- **Upload Flow:** `docs/APP/DECISIONS/upload-persistence.md`

