# File Validation

## Strategia

- ✅ **Filename sanitization**: Necessaria
- ✅ **Path traversal protection**: Necessaria
- ❌ **Magic number validation**: Future implementation

---

## Filename Sanitization

### Implementazione Client-Side (Flutter)

```dart
// lib/features/upload/utils/filename_sanitizer.dart
class FilenameSanitizer {
  static String sanitize(String filename) {
    // Rimuovi path traversal
    filename = filename.replaceAll(RegExp(r'\.\./|\.\.\\'), '');
    
    // Rimuovi caratteri speciali
    filename = filename.replaceAll(RegExp(r'[<>:"|?*\\/]'), '_');
    
    // Rimuovi caratteri controllo
    filename = filename.replaceAll(RegExp(r'[\x00-\x1F]'), '');
    
    // Limita lunghezza (max 255 caratteri)
    if (filename.length > 255) {
      final extension = filename.split('.').last;
      final nameWithoutExt = filename.substring(0, filename.lastIndexOf('.'));
      filename = '${nameWithoutExt.substring(0, 255 - extension.length - 1)}.$extension';
    }
    
    // Rimuovi spazi multipli
    filename = filename.replaceAll(RegExp(r'\s+'), ' ');
    
    return filename.trim();
  }
}
```

### Implementazione Server-Side (FastAPI)

```python
# app/utils/file_validation.py
import re
from pathlib import Path

def sanitize_filename(filename: str) -> str:
    """Sanitizza filename per evitare errori e path traversal.
    
    Args:
        filename: Filename originale
        
    Returns:
        Filename sanitizzato
    """
    # Rimuovi path traversal
    filename = re.sub(r'\.\./|\.\.\\', '', filename)
    
    # Rimuovi caratteri speciali
    filename = re.sub(r'[<>:"|?*\\/]', '_', filename)
    
    # Rimuovi caratteri controllo
    filename = re.sub(r'[\x00-\x1F]', '', filename)
    
    # Limita lunghezza (max 255 caratteri)
    if len(filename) > 255:
        extension = Path(filename).suffix
        name_without_ext = filename[:-len(extension)]
        filename = f"{name_without_ext[:255-len(extension)-1]}{extension}"
    
    # Rimuovi spazi multipli
    filename = re.sub(r'\s+', ' ', filename)
    
    return filename.strip()
```

---

## Path Traversal Protection

### Implementazione

```python
# app/utils/file_validation.py
from pathlib import Path
from fastapi import HTTPException

def validate_file_path(file_path: str, base_path: str) -> None:
    """Valida che file path non esca da base_path.
    
    Args:
        file_path: Path file da validare
        base_path: Path base consentito
        
    Raises:
        HTTPException: 400 se path traversal rilevato
    """
    resolved_path = Path(file_path).resolve()
    resolved_base = Path(base_path).resolve()
    
    try:
        resolved_path.relative_to(resolved_base)
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail="Path traversal detected"
        )
```

**Uso:**
```python
# Prima di salvare file
validate_file_path(file_path, settings.VIDEOS_PATH)
```
