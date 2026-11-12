# Progress Tracking Server-Side

## Strategia

- **Progress tracking durante salvataggio file** (leggero e preciso)
- **Aggiornamento ogni 1MB** (non ogni chunk 64KB)
- **Callback opzionale** per aggiornare upload queue in tempo reale

---

## Implementazione

**File:** `app/core/storage.py`

```python
async def save_file_to_disk(
    file: UploadFile, 
    file_path: str, 
    on_progress: Optional[Callable[[int, int], None]] = None,
    total_size: Optional[int] = None
) -> None:
    """Salva file su disco con progress tracking.
    
    Args:
        file: File da salvare
        file_path: Path finale del file
        on_progress: Callback per aggiornare progress (opzionale)
        total_size: Dimensione totale file in bytes (opzionale)
    """
    total_written = 0
    last_update = 0
    update_threshold = 1024 * 1024  # 1MB - aggiorna progress ogni 1MB
    
    async with aiofiles.open(temp_path, 'wb') as f:
        async for chunk in file.stream():
            await f.write(chunk)
            total_written += len(chunk)
            
            # Aggiorna progress ogni 1MB
            if on_progress and (total_written - last_update >= update_threshold or total_written == total_size):
                if total_size:
                    on_progress(total_written, total_size)
                last_update = total_written
    
    # Aggiorna progress finale (100%)
    if on_progress and total_size:
        on_progress(total_written, total_size)
```

**File:** `app/api/routes/videos.py`

```python
# Callback per aggiornare progress durante upload
def update_progress(uploaded_bytes: int, total_bytes: int) -> None:
    """Aggiorna progress upload queue durante il salvataggio"""
    upload_queue_service.update_upload_progress(
        upload_id=upload_queue.id,
        uploaded_bytes=uploaded_bytes,
    )

# Salva file con progress tracking
await save_file_to_disk(
    file, 
    video.file_path,
    on_progress=update_progress,
    total_size=file_size
)
```

---

## Update Upload Queue Progress

**File:** `app/services/upload_queue_service.py`

```python
def update_upload_progress(
    self,
    upload_id: str,
    uploaded_bytes: int,
) -> UploadQueue:
    """Aggiorna progress upload.
    
    Args:
        upload_id: ID upload queue
        uploaded_bytes: Bytes uploadati
        
    Returns:
        UploadQueue aggiornata
    """
    upload_queue = self.db.query(UploadQueue).filter(
        UploadQueue.id == upload_id
    ).first()
    
    upload_queue.uploaded_bytes = uploaded_bytes
    upload_queue.progress = uploaded_bytes / upload_queue.total_bytes if upload_queue.total_bytes > 0 else 0.0
    
    self.db.commit()
    self.db.refresh(upload_queue)
    
    return upload_queue
```
