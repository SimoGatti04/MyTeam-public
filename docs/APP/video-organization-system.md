# Sistema di Organizzazione Video

## Panoramica

Il sistema di organizzazione video permette agli utenti di organizzare, ordinare e filtrare i video in base a diversi criteri per facilitare la ricerca e la gestione di grandi collezioni di video, in particolare per video di allenamenti calcistici.

---

## Funzionalità Principali

### 1. Ordinamento Video

Gli utenti possono ordinare i video in base a:

- **Data di aggiunta** (`uploadedAt` / `created_at`)
  - Crescente (più vecchi prima)
  - Decrescente (più recenti prima)

- **Data di realizzazione** (`recordedAt` / `recorded_date`)
  - Crescente (più vecchi prima)
  - Decrescente (più recenti prima)
  - **Nota**: La data di realizzazione può essere:
    - Recuperata automaticamente dai metadati del video (se disponibile)
    - Impostata manualmente dall'utente
    - Modificata in qualsiasi momento

- **Nome** (`title`)
  - Alfabetico A-Z
  - Alfabetico Z-A

- **Nome giocatori partecipanti** (tag giocatori)
  - Ordinamento basato sul primo giocatore taggato (alfabetico)

- **Tipo di allenamento/esercizi** (tag allenamento)
  - Ordinamento basato sul primo tag allenamento (alfabetico)

- **Squadra** (tag squadra)
  - Ordinamento alfabetico per nome squadra

### 2. Filtraggio Video

Gli utenti possono filtrare i video in base a:

#### Filtri per Data di Realizzazione

- **Per mese**
  - Seleziona un mese specifico (es: Gennaio 2024)
  - Mostra tutti i video registrati in quel mese

- **Per stagione**
  - Le stagioni vanno da **luglio dell'anno precedente a giugno dell'anno successivo**
  - Esempi:
    - Stagione 2024/2025: 1 luglio 2024 - 30 giugno 2025
    - Stagione 2023/2024: 1 luglio 2023 - 30 giugno 2024
  - Formato visualizzazione: "2024/2025", "2023/2024", etc.
  - Calcolo automatico della stagione in base alla data di realizzazione

- **Per settimana**
  - Seleziona una settimana specifica (inizio settimana: lunedì)
  - Mostra tutti i video registrati in quella settimana
  - Formato: "Settimana 1-7 Gennaio 2024" o "1-7 Gen 2024"

- **Per giorno**
  - Seleziona un giorno specifico
  - Mostra tutti i video registrati in quel giorno
  - Formato: "15 Gennaio 2024" o "15 Gen 2024"

- **Intervallo personalizzato**
  - Seleziona data inizio e data fine tramite calendario
  - Mostra tutti i video registrati nell'intervallo selezionato
  - Validazione: data inizio deve essere <= data fine

#### Filtri per Contenuto

- **Giocatori partecipanti**
  - Filtra per uno o più giocatori taggati
  - Supporto multi-selezione
  - Mostra video che contengono almeno uno dei giocatori selezionati (OR logic)

- **Tipo di allenamento/esercizi**
  - Filtra per uno o più tipi di allenamento/esercizi taggati
  - Supporto multi-selezione
  - Mostra video che contengono almeno uno dei tipi selezionati (OR logic)

- **Squadra**
  - Filtra per una o più squadre taggate
  - Supporto multi-selezione
  - Mostra video che contengono almeno una delle squadre selezionate (OR logic)

#### Combinazione Filtri

- I filtri possono essere combinati (AND logic tra categorie diverse)
  - Esempio: "Stagione 2024/2025" AND "Giocatore: Mario Rossi" AND "Tipo: Riscaldamento"
  - Mostra video che soddisfano TUTTI i criteri selezionati

---

## Modelli Dati

### Video Entity (Aggiornato)

```dart
class Video {
  // ... campi esistenti ...
  
  final DateTime uploadedAt;           // Data di aggiunta (non modificabile)
  final DateTime? recordedAt;          // Data di realizzazione (modificabile)
  final DateTime? lastModifiedAt;      // Ultima modifica
  
  // Relazioni con Tag, Giocatori, Squadre, Note
  final List<String>? playerIds;        // Riferimenti a giocatori taggati
  final List<String>? trainingTypeIds; // Riferimenti a tipi di allenamento/esercizi
  final List<String>? teamIds;         // Riferimenti a squadre taggate
  final List<String>? noteIds;         // Riferimenti a note associate
}
```

### Player Entity (Giocatore)

```dart
class Player {
  final String id;
  final String name;                   // Nome completo (es: "Mario Rossi")
  final String? description;            // Note aggiuntive (opzionale)
  final String? photoUrl;               // Foto profilo (opzionale)
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int videoCount;                // Numero video associati (calcolato)
}

class VideoPlayer {
  final String id;
  final String videoId;
  final String playerId;
  final DateTime taggedAt;              // Quando è stato taggato
}
```

### TrainingType Entity (Tipo di Allenamento/Esercizio)

```dart
class TrainingType {
  final String id;
  final String name;                   // Nome tipo (es: "Riscaldamento", "Tecnica", "Partita")
  final String? description;            // Descrizione dettagliata (opzionale)
  final String? category;               // Categoria (es: "Riscaldamento", "Esercizio", "Partita")
  final String? color;                  // Colore per UI (hex, opzionale)
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int videoCount;                 // Numero video associati (calcolato)
}

class VideoTrainingType {
  final String id;
  final String videoId;
  final String trainingTypeId;
  final DateTime taggedAt;
}
```

### Team Entity (Squadra)

```dart
class Team {
  final String id;
  final String name;                    // Nome squadra (es: "Prima Squadra", "Under 19")
  final String? description;            // Descrizione (opzionale)
  final String? logoUrl;                 // Logo squadra (opzionale)
  final String? color;                  // Colore per UI (hex, opzionale)
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int videoCount;                 // Numero video associati (calcolato)
}

class VideoTeam {
  final String id;
  final String videoId;
  final String teamId;
  final DateTime taggedAt;
}
```

### Note Entity (Nota)

```dart
class Note {
  final String id;
  final String videoId;
  final String content;                 // Contenuto nota (testo)
  final Duration? timestamp;            // Timestamp nel video (opzionale, se nota è relativa a un momento specifico)
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isPrivate;                 // Sempre true per app privata, ma utile per organizzazione
}
```

---

## Database Schema (Server)

### Video Table (Aggiornato)

```python
class Video(Base):
    # ... campi esistenti ...
    
    # Timestamps
    created_at = Column(DateTime, default=func.now(), nullable=False)  # Data di aggiunta
    recorded_date = Column(DateTime, nullable=True)                    # Data di realizzazione (modificabile)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)
```

### Nuove Tabelle

```python
# Giocatori
class Player(Base):
    __tablename__ = "players"
    
    id = Column(String, primary_key=True)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    photo_url = Column(String(500), nullable=True)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)

class VideoPlayer(Base):
    __tablename__ = "video_players"
    
    id = Column(String, primary_key=True)
    video_id = Column(String, ForeignKey("videos.id"), nullable=False)
    player_id = Column(String, ForeignKey("players.id"), nullable=False)
    tagged_at = Column(DateTime, default=func.now(), nullable=False)
    
    # Unique constraint: un giocatore può essere taggato una sola volta per video
    __table_args__ = (UniqueConstraint('video_id', 'player_id'),)

# Tipi di Allenamento/Esercizi
class TrainingType(Base):
    __tablename__ = "training_types"
    
    id = Column(String, primary_key=True)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    category = Column(String(100), nullable=True)  # "Riscaldamento", "Esercizio", "Partita"
    color = Column(String(7), nullable=True)        # Hex color
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)

class VideoTrainingType(Base):
    __tablename__ = "video_training_types"
    
    id = Column(String, primary_key=True)
    video_id = Column(String, ForeignKey("videos.id"), nullable=False)
    training_type_id = Column(String, ForeignKey("training_types.id"), nullable=False)
    tagged_at = Column(DateTime, default=func.now(), nullable=False)
    
    __table_args__ = (UniqueConstraint('video_id', 'training_type_id'),)

# Squadre
class Team(Base):
    __tablename__ = "teams"
    
    id = Column(String, primary_key=True)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    logo_url = Column(String(500), nullable=True)
    color = Column(String(7), nullable=True)  # Hex color
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)

class VideoTeam(Base):
    __tablename__ = "video_teams"
    
    id = Column(String, primary_key=True)
    video_id = Column(String, ForeignKey("videos.id"), nullable=False)
    team_id = Column(String, ForeignKey("teams.id"), nullable=False)
    tagged_at = Column(DateTime, default=func.now(), nullable=False)
    
    __table_args__ = (UniqueConstraint('video_id', 'team_id'),)

# Note
class Note(Base):
    __tablename__ = "notes"
    
    id = Column(String, primary_key=True)
    video_id = Column(String, ForeignKey("videos.id"), nullable=False)
    content = Column(Text, nullable=False)
    timestamp = Column(Integer, nullable=True)  # Secondi nel video (opzionale)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)
    is_private = Column(Boolean, default=True, nullable=False)
```

---

## API Endpoints (Server)

### Video Endpoints (Aggiornati)

```
GET /api/videos
  Query Parameters:
    - sort_by: string (uploaded_at, recorded_date, title, player, training_type, team)
    - sort_order: string (asc, desc)
    - recorded_date_from: datetime (ISO 8601)
    - recorded_date_to: datetime (ISO 8601)
    - recorded_month: int (1-12)
    - recorded_year: int
    - recorded_season: string (es: "2024/2025")
    - recorded_week_start: datetime (inizio settimana)
    - recorded_week_end: datetime (fine settimana)
    - recorded_day: datetime (giorno specifico)
    - player_ids: string[] (array di player IDs)
    - training_type_ids: string[] (array di training type IDs)
    - team_ids: string[] (array di team IDs)
    - search: string (ricerca per nome/descrizione)

PUT /api/videos/{video_id}
  Body:
    - recorded_date: datetime (ISO 8601, opzionale)
    - title: string (opzionale)
    - description: string (opzionale)
```

### Player Endpoints

```
GET /api/players
  Query Parameters:
    - search: string (ricerca per nome)

GET /api/players/{player_id}

POST /api/players
  Body:
    - name: string (required)
    - description: string (opzionale)
    - photo_url: string (opzionale)

PUT /api/players/{player_id}
  Body:
    - name: string (opzionale)
    - description: string (opzionale)
    - photo_url: string (opzionale)

DELETE /api/players/{player_id}

POST /api/videos/{video_id}/players
  Body:
    - player_id: string (required)

DELETE /api/videos/{video_id}/players/{player_id}
```

### TrainingType Endpoints

```
GET /api/training-types
  Query Parameters:
    - search: string (ricerca per nome)
    - category: string (filtro per categoria)

GET /api/training-types/{training_type_id}

POST /api/training-types
  Body:
    - name: string (required)
    - description: string (opzionale)
    - category: string (opzionale)
    - color: string (opzionale, hex)

PUT /api/training-types/{training_type_id}
  Body:
    - name: string (opzionale)
    - description: string (opzionale)
    - category: string (opzionale)
    - color: string (opzionale)

DELETE /api/training-types/{training_type_id}

POST /api/videos/{video_id}/training-types
  Body:
    - training_type_id: string (required)

DELETE /api/videos/{video_id}/training-types/{training_type_id}
```

### Team Endpoints

```
GET /api/teams
  Query Parameters:
    - search: string (ricerca per nome)

GET /api/teams/{team_id}

POST /api/teams
  Body:
    - name: string (required)
    - description: string (opzionale)
    - logo_url: string (opzionale)
    - color: string (opzionale, hex)

PUT /api/teams/{team_id}
  Body:
    - name: string (opzionale)
    - description: string (opzionale)
    - logo_url: string (opzionale)
    - color: string (opzionale)

DELETE /api/teams/{team_id}

POST /api/videos/{video_id}/teams
  Body:
    - team_id: string (required)

DELETE /api/videos/{video_id}/teams/{team_id}
```

### Note Endpoints

```
GET /api/videos/{video_id}/notes

GET /api/videos/{video_id}/notes/{note_id}

POST /api/videos/{video_id}/notes
  Body:
    - content: string (required)
    - timestamp: int (opzionale, secondi nel video)

PUT /api/videos/{video_id}/notes/{note_id}
  Body:
    - content: string (opzionale)
    - timestamp: int (opzionale)

DELETE /api/videos/{video_id}/notes/{note_id}
```

---

## UI/UX (App)

### Video List Screen (Aggiornato)

#### Barra di Filtri e Ordinamento

```
┌─────────────────────────────────────────┐
│ [🔍 Cerca...]  [⚙️ Filtri]  [⇅ Ordina] │
└─────────────────────────────────────────┘
```

#### Pannello Filtri

```
┌─────────────────────────────────────────┐
│ Filtri Video                            │
├─────────────────────────────────────────┤
│ 📅 Data Realizzazione                   │
│   ○ Nessun filtro                       │
│   ● Mese                                │
│     [Gennaio 2024 ▼]                    │
│   ○ Stagione                            │
│     [2024/2025 ▼]                       │
│   ○ Settimana                           │
│     [1-7 Gen 2024 ▼]                    │
│   ○ Giorno                              │
│     [15 Gen 2024 ▼]                     │
│   ○ Intervallo personalizzato            │
│     [Da: 01 Gen 2024]                   │
│     [A:  31 Gen 2024]                   │
├─────────────────────────────────────────┤
│ 👥 Giocatori                            │
│   [Mario Rossi] [Luca Bianchi] ...      │
│   [+ Aggiungi giocatore]                 │
├─────────────────────────────────────────┤
│ 🏃 Tipo Allenamento                     │
│   [Riscaldamento] [Tecnica] ...         │
│   [+ Aggiungi tipo]                     │
├─────────────────────────────────────────┤
│ ⚽ Squadra                               │
│   [Prima Squadra] [Under 19] ...        │
│   [+ Aggiungi squadra]                  │
├─────────────────────────────────────────┤
│ [Pulisci filtri]  [Applica filtri]      │
└─────────────────────────────────────────┘
```

#### Pannello Ordinamento

```
┌─────────────────────────────────────────┐
│ Ordina per                              │
├─────────────────────────────────────────┤
│ ● Data aggiunta (più recenti)           │
│ ○ Data aggiunta (più vecchi)            │
│ ○ Data realizzazione (più recenti)      │
│ ○ Data realizzazione (più vecchi)      │
│ ○ Nome (A-Z)                            │
│ ○ Nome (Z-A)                            │
│ ○ Giocatore (A-Z)                       │
│ ○ Tipo allenamento (A-Z)                │
│ ○ Squadra (A-Z)                         │
└─────────────────────────────────────────┘
```

### Video Detail Screen (Aggiornato)

#### Sezione Informazioni Video

```
┌─────────────────────────────────────────┐
│ Video: "Allenamento 15 Gennaio"         │
├─────────────────────────────────────────┤
│ 📅 Data aggiunta: 20 Gen 2024           │
│ 📹 Data realizzazione: 15 Gen 2024     │
│         [✏️ Modifica]                   │
├─────────────────────────────────────────┤
│ 👥 Giocatori:                           │
│   [Mario Rossi] [Luca Bianchi]           │
│   [+ Aggiungi giocatore]                │
├─────────────────────────────────────────┤
│ 🏃 Tipo Allenamento:                    │
│   [Riscaldamento] [Tecnica]             │
│   [+ Aggiungi tipo]                     │
├─────────────────────────────────────────┤
│ ⚽ Squadra:                              │
│   [Prima Squadra]                       │
│   [+ Aggiungi squadra]                  │
├─────────────────────────────────────────┤
│ 📝 Note:                                │
│   [Aggiungi nota]                       │
│   • Nota 1 (00:15)                      │
│   • Nota 2                              │
└─────────────────────────────────────────┘
```

---

## Logica di Calcolo Stagione

La stagione viene calcolata automaticamente in base alla data di realizzazione:

```dart
/// Calcola la stagione per una data specifica
/// Stagione: da luglio dell'anno precedente a giugno dell'anno successivo
String calculateSeason(DateTime date) {
  final year = date.year;
  final month = date.month;
  
  // Se il mese è tra gennaio e giugno, la stagione inizia l'anno precedente
  if (month >= 1 && month <= 6) {
    return '${year - 1}/${year}';
  }
  // Se il mese è tra luglio e dicembre, la stagione inizia nell'anno corrente
  else {
    return '$year/${year + 1}';
  }
}

/// Ottiene l'intervallo di date per una stagione
/// Es: "2024/2025" -> DateTime(2024, 7, 1) - DateTime(2025, 6, 30)
class SeasonRange {
  final DateTime start; // 1 luglio anno precedente
  final DateTime end;   // 30 giugno anno successivo
  
  SeasonRange.fromSeasonString(String season) {
    final parts = season.split('/');
    final startYear = int.parse(parts[0]);
    final endYear = int.parse(parts[1]);
    
    start = DateTime(startYear, 7, 1);
    end = DateTime(endYear, 6, 30, 23, 59, 59);
  }
}
```

---

## Estrazione Data Realizzazione da Metadati

La data di realizzazione può essere estratta automaticamente dai metadati del video se disponibile:

```python
# Server-side: Estrazione da FFprobe
def extract_recorded_date_from_metadata(video_metadata: dict) -> Optional[datetime]:
    """
    Estrae la data di realizzazione dai metadati video.
    Cerca in diversi campi comuni:
    - creation_time (formato ISO o varianti)
    - com.apple.quicktime.creationdate (QuickTime)
    - date (formato vario)
    """
    if not video_metadata:
        return None
    
    # Cerca in video_metadata (JSON da FFprobe)
    creation_time = video_metadata.get('creation_time')
    if creation_time:
        try:
            # Prova a parsare in vari formati
            return parse_datetime(creation_time)
        except:
            pass
    
    return None
```

```dart
// Client-side: Estrazione da metadati
DateTime? extractRecordedDateFromMetadata(Map<String, dynamic>? metadata) {
  if (metadata == null) return null;
  
  // Cerca creation_time nei metadati
  final creationTime = metadata['creation_time'];
  if (creationTime != null) {
    try {
      return DateTime.parse(creationTime.toString());
    } catch (e) {
      return null;
    }
  }
  
  return null;
}
```

---

## Implementazione Filtri Data

### Filtro per Mese

```dart
List<Video> filterByMonth(List<Video> videos, int month, int year) {
  return videos.where((video) {
    if (video.recordedAt == null) return false;
    return video.recordedAt!.month == month && 
           video.recordedAt!.year == year;
  }).toList();
}
```

### Filtro per Stagione

```dart
List<Video> filterBySeason(List<Video> videos, String season) {
  final range = SeasonRange.fromSeasonString(season);
  return videos.where((video) {
    if (video.recordedAt == null) return false;
    return video.recordedAt!.isAfter(range.start.subtract(Duration(seconds: 1))) &&
           video.recordedAt!.isBefore(range.end.add(Duration(seconds: 1)));
  }).toList();
}
```

### Filtro per Settimana

```dart
List<Video> filterByWeek(List<Video> videos, DateTime weekStart) {
  final weekEnd = weekStart.add(Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
  return videos.where((video) {
    if (video.recordedAt == null) return false;
    return video.recordedAt!.isAfter(weekStart.subtract(Duration(seconds: 1))) &&
           video.recordedAt!.isBefore(weekEnd.add(Duration(seconds: 1)));
  }).toList();
}
```

### Filtro per Giorno

```dart
List<Video> filterByDay(List<Video> videos, DateTime day) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = dayStart.add(Duration(days: 1)).subtract(Duration(seconds: 1));
  return videos.where((video) {
    if (video.recordedAt == null) return false;
    return video.recordedAt!.isAfter(dayStart.subtract(Duration(seconds: 1))) &&
           video.recordedAt!.isBefore(dayEnd.add(Duration(seconds: 1)));
  }).toList();
}
```

### Filtro per Intervallo Personalizzato

```dart
List<Video> filterByDateRange(List<Video> videos, DateTime start, DateTime end) {
  return videos.where((video) {
    if (video.recordedAt == null) return false;
    return video.recordedAt!.isAfter(start.subtract(Duration(seconds: 1))) &&
           video.recordedAt!.isBefore(end.add(Duration(seconds: 1)));
  }).toList();
}
```

---

## Ordinamento Video

```dart
enum VideoSortOption {
  uploadedAtAsc,      // Data aggiunta crescente
  uploadedAtDesc,     // Data aggiunta decrescente
  recordedAtAsc,       // Data realizzazione crescente
  recordedAtDesc,      // Data realizzazione decrescente
  titleAsc,            // Nome A-Z
  titleDesc,           // Nome Z-A
  playerAsc,           // Primo giocatore A-Z
  playerDesc,          // Primo giocatore Z-A
  trainingTypeAsc,     // Primo tipo allenamento A-Z
  trainingTypeDesc,    // Primo tipo allenamento Z-A
  teamAsc,             // Squadra A-Z
  teamDesc,            // Squadra Z-A
}

List<Video> sortVideos(List<Video> videos, VideoSortOption option) {
  final sorted = List<Video>.from(videos);
  
  switch (option) {
    case VideoSortOption.uploadedAtAsc:
      sorted.sort((a, b) => a.uploadedAt.compareTo(b.uploadedAt));
      break;
    case VideoSortOption.uploadedAtDesc:
      sorted.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      break;
    case VideoSortOption.recordedAtAsc:
      sorted.sort((a, b) {
        if (a.recordedAt == null && b.recordedAt == null) return 0;
        if (a.recordedAt == null) return 1;
        if (b.recordedAt == null) return -1;
        return a.recordedAt!.compareTo(b.recordedAt!);
      });
      break;
    case VideoSortOption.recordedAtDesc:
      sorted.sort((a, b) {
        if (a.recordedAt == null && b.recordedAt == null) return 0;
        if (a.recordedAt == null) return 1;
        if (b.recordedAt == null) return -1;
        return b.recordedAt!.compareTo(a.recordedAt!);
      });
      break;
    case VideoSortOption.titleAsc:
      sorted.sort((a, b) => a.title.compareTo(b.title));
      break;
    case VideoSortOption.titleDesc:
      sorted.sort((a, b) => b.title.compareTo(a.title));
      break;
    // ... altri casi per player, trainingType, team
    // Richiedono join con tabelle correlate o caricamento dati aggiuntivi
  }
  
  return sorted;
}
```

---

## Note di Implementazione

### Priorità Implementazione

1. **Fase 1: Data Realizzazione**
   - Aggiungere campo `recorded_date` al database
   - Estrazione automatica da metadati (se disponibile)
   - UI per modifica manuale data realizzazione
   - Filtri base per data (mese, stagione, settimana, giorno, intervallo)

2. **Fase 2: Tag Giocatori**
   - Creare tabelle `players` e `video_players`
   - CRUD giocatori
   - Tagging video con giocatori
   - Filtro e ordinamento per giocatori

3. **Fase 3: Tag Allenamento/Esercizi**
   - Creare tabelle `training_types` e `video_training_types`
   - CRUD tipi allenamento
   - Tagging video con tipi allenamento
   - Filtro e ordinamento per tipo allenamento

4. **Fase 4: Tag Squadra**
   - Creare tabelle `teams` e `video_teams`
   - CRUD squadre
   - Tagging video con squadre
   - Filtro e ordinamento per squadra

5. **Fase 5: Note**
   - Creare tabella `notes`
   - CRUD note
   - Associazione note a video (con timestamp opzionale)

### Considerazioni Performance

- **Indici Database**: Aggiungere indici su:
  - `videos.recorded_date`
  - `video_players.video_id`, `video_players.player_id`
  - `video_training_types.video_id`, `video_training_types.training_type_id`
  - `video_teams.video_id`, `video_teams.team_id`
  - `notes.video_id`

- **Query Ottimizzate**: Usare JOIN per filtri e ordinamenti che coinvolgono tabelle correlate

- **Caching**: Cache locale per liste giocatori, tipi allenamento, squadre (cambiano raramente)

- **Paginazione**: Mantenere paginazione anche con filtri attivi

---

## Riferimenti

- [Modelli Dati Generali](../GENERAL/DATA-MODELS.md)
- [Modelli Dati Server](../SERVER/DATA-MODELS.md)
- [Modelli Dati App](../APP/DATA-MODELS.md)
- [Decisioni Video List](DECISIONS/video-list.md)

