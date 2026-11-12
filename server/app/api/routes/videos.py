"""Video API routes"""
import os
from pathlib import Path
from typing import Optional, List
from datetime import datetime
from fastapi import APIRouter, UploadFile, Form, BackgroundTasks, Depends, HTTPException, Request, Query, Header
from fastapi.responses import FileResponse, StreamingResponse, Response
from sqlalchemy.orm import Session
from sqlalchemy import or_, desc, asc, and_, func
from app.core.database import get_db
from app.core.config import get_settings
from app.core.storage import save_file_to_disk, check_disk_space
from app.services.video_service import VideoService
from app.services.upload_queue_service import UploadQueueService
from app.services.background_tasks import extract_metadata_task, generate_thumbnail_task
from app.utils.file_validation import validate_file
from app.schemas.video import VideoResponse, VideoListResponse, VideoListItem
from app.models.video import Video
from app.models.player import VideoPlayer
from app.models.training_type import VideoTrainingType
from app.models.team import VideoTeam
from app.models.player import VideoPlayer, Player
from app.models.training_type import VideoTrainingType, TrainingType
from app.models.team import VideoTeam, Team

settings = get_settings()
router = APIRouter()


@router.post("/api/videos", response_model=VideoResponse)  # Timeout configurato in uvicorn
async def upload_video(
    request: Request,
    file: UploadFile,
    title: str = Form(None),
    original_resolution_width: int = Form(None),
    original_resolution_height: int = Form(None),
    original_framerate: float = Form(None),
    compressed_framerate: float = Form(None),
    original_file_size: int = Form(None),
    recorded_date: str = Form(None),
    background_tasks: BackgroundTasks = BackgroundTasks(),
    db: Session = Depends(get_db),
):
    """Upload video compresso al server.
    
    IMPORTANTE: Questo endpoint riceve file multipart/form-data.
    Il Content-Length header contiene la dimensione totale del multipart,
    non solo il file. La validazione della dimensione viene fatta durante
    il salvataggio del file, non usando Content-Length.
    """
    # Log immediato per verificare che la richiesta arrivi al server
    import logging
    import sys
    logger = logging.getLogger(__name__)
    
    # Forza output su stdout/stderr (importante per Windows)
    print("=" * 80, file=sys.stderr, flush=True)
    print("[UPLOAD] Richiesta ricevuta!", file=sys.stderr, flush=True)
    print(f"[UPLOAD] Method: {request.method}", file=sys.stderr, flush=True)
    print(f"[UPLOAD] URL: {request.url}", file=sys.stderr, flush=True)
    print(f"[UPLOAD] Headers: {dict(request.headers)}", file=sys.stderr, flush=True)
    
    logger.info("=" * 80)
    logger.info("[UPLOAD] Richiesta ricevuta!")
    logger.info(f"[UPLOAD] Method: {request.method}")
    logger.info(f"[UPLOAD] URL: {request.url}")
    # IMPORTANTE: Per multipart/form-data, il Content-Length header contiene la dimensione
    # totale del multipart (file + boundary + altri campi form), non solo il file.
    # Non possiamo usare Content-Length per validare la dimensione del file compresso.
    # La validazione verrà fatta durante il salvataggio del file.
    
    # Log per debug
    content_type = request.headers.get('content-type', '')
    content_length = request.headers.get('content-length', 'N/A')
    logger.info(f"[Upload] Content-Type: {content_type}")
    logger.info(f"[Upload] Content-Length header: {content_length} (non affidabile per multipart)")
    logger.info(f"[Upload] original_file_size: {original_file_size}")
    logger.info(f"[Upload] MAX_UPLOAD_SIZE: {settings.MAX_UPLOAD_SIZE}")
    
    # IMPORTANTE: Per multipart/form-data, NON validare Content-Length
    # Il Content-Length include boundary e altri campi form, non solo il file
    # La validazione della dimensione verrà fatta durante il salvataggio del file
    validate_file(file, request_headers=None)  # Solo validazione formato, non dimensione
    logger.info("[Upload] validate_file completato (solo formato)")
    
    # Check disk space se original_file_size > 10GB (stima conservativa)
    # Usiamo original_file_size come stima massima
    if original_file_size and original_file_size > 10 * 1024 * 1024 * 1024:
        check_disk_space(original_file_size, settings.VIDEOS_PATH)
    
    # Crea upload queue entry
    upload_queue_service = UploadQueueService(db)
    upload_queue = upload_queue_service.create_upload_queue_entry(
        filename=file.filename or "unknown",
        file_path="",  # Verrà aggiornato dopo salvataggio
        file_size=original_file_size or 0,  # Usa original_file_size per stima
    )
    
    # Crea video service
    video_service = VideoService(db)
    
    # Log recorded_date per debug
    logger.info(f"[Upload] recorded_date received: {recorded_date}")
    
    # Crea video entry (senza salvare file ancora)
    video = video_service.save_video(
        file=file,
        title=title or file.filename or "Untitled",
        original_resolution_width=original_resolution_width,
        original_resolution_height=original_resolution_height,
        original_framerate=original_framerate,
        compressed_framerate=compressed_framerate,
        original_file_size=original_file_size,
        recorded_date=recorded_date,
    )
    
    logger.info(f"[Upload] Video created with recorded_date: {video.recorded_date}")
    
    # Aggiorna upload queue con video_id e file_path
    upload_queue_service.update_upload_queue_status(
        upload_id=upload_queue.id,
        status="processing",
        video_id=video.id,
        progress=0.0,
    )
    
    # Callback per aggiornare progress durante upload
    def update_progress(uploaded_bytes: int, total_bytes: int) -> None:
        """Aggiorna progress upload queue durante il salvataggio"""
        try:
            upload_queue_service.update_upload_progress(
                upload_id=upload_queue.id,
                uploaded_bytes=uploaded_bytes,
            )
        except Exception as e:
            # Log errore ma non interrompere upload
            logger.warning(f"Errore aggiornamento progress: {e}")
    
    try:
        # Salva file con progress tracking
        # IMPORTANTE: Per multipart/form-data, validiamo la dimensione durante il salvataggio
        # invece di usare Content-Length (che include boundary e altri campi form)
        await save_file_to_disk(
            file, 
            video.file_path,
            on_progress=update_progress,
            total_size=original_file_size,  # Stima per progress (opzionale)
            max_size=settings.MAX_UPLOAD_SIZE,  # Limite massimo per validazione (50GB)
        )
        
        # Ottieni dimensione file effettiva
        actual_file_size = os.path.getsize(video.file_path)
        
        # Validazione finale: verifica che la dimensione effettiva non superi il limite
        if actual_file_size > settings.MAX_UPLOAD_SIZE:
            # Rimuovi file se troppo grande
            if os.path.exists(video.file_path):
                os.remove(video.file_path)
            raise HTTPException(
                status_code=413,
                detail=f"File troppo grande. Dimensione effettiva: {actual_file_size / (1024**3):.2f} GB. Dimensione massima: {settings.MAX_UPLOAD_SIZE / (1024**3):.1f} GB"
            )
        
        # Aggiorna video con dimensione effettiva
        video = video_service.update_video_file_size(video.id, actual_file_size)
        
        # Aggiorna upload queue progress finale (garantisce 100%)
        upload_queue_service.update_upload_progress(
            upload_id=upload_queue.id,
            uploaded_bytes=actual_file_size,
        )
        
        # Aggiorna upload queue status a completed
        upload_queue_service.update_upload_queue_status(
            upload_id=upload_queue.id,
            status="completed",
            progress=1.0,
        )
        
        # Background tasks (non bloccanti)
        background_tasks.add_task(extract_metadata_task, video.id)
        background_tasks.add_task(generate_thumbnail_task, video.id)
        
        return video
        
    except Exception as e:
        # Cleanup in caso di errore
        import logging
        logger = logging.getLogger(__name__)
        logger.error(f"Errore durante salvataggio file: {str(e)}", exc_info=True)
        
        # Rimuovi file se esiste
        if video.file_path and os.path.exists(video.file_path):
            try:
                os.remove(video.file_path)
            except:
                pass
        
        # Rimuovi file temporaneo se esiste
        temp_path = video.file_path + '.tmp'
        if os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except:
                pass
        
        # Aggiorna upload queue status a error
        try:
            upload_queue_service.update_upload_queue_status(
                upload_id=upload_queue.id,
                status="error",
                progress=0.0,
            )
        except:
            pass
        
        # Aggiorna video status a error
        try:
            video_service.update_video_status(video.id, "error")
        except:
            pass
        
        # Rollback database
        try:
            db.rollback()
        except:
            pass
        
        raise HTTPException(
            status_code=500,
            detail=f"Errore durante salvataggio file: {str(e)}"
        )


@router.get("/api/videos", response_model=VideoListResponse)
async def list_videos(
    page: int = Query(1, ge=1, description="Page number"),
    limit: int = Query(20, ge=1, le=100, description="Items per page"),
    search: Optional[str] = Query(None, description="Search in title/filename/players/training_types/teams/years"),
    sort: Optional[str] = Query("date_desc", description="Sort option"),
    status: Optional[str] = Query(None, description="Filter by status"),
    # Filtri data
    recorded_date_from: Optional[datetime] = Query(None, description="Filter by recorded date from"),
    recorded_date_to: Optional[datetime] = Query(None, description="Filter by recorded date to"),
    recorded_month: Optional[int] = Query(None, ge=1, le=12, description="Filter by recorded month (1-12)"),
    recorded_year: Optional[int] = Query(None, description="Filter by recorded year"),
    # Filtri per entità
    player_ids: Optional[str] = Query(None, description="Comma-separated player IDs"),
    training_type_ids: Optional[str] = Query(None, description="Comma-separated training type IDs"),
    team_ids: Optional[str] = Query(None, description="Comma-separated team IDs"),
    db: Session = Depends(get_db),
):
    """Lista video con paginazione, ricerca avanzata, filtri e sorting.
    
    Args:
        page: Numero pagina (default: 1)
        limit: Elementi per pagina (default: 20, max: 100)
        search: Ricerca avanzata (titolo, filename, giocatori, esercizi, squadre, anni)
        sort: Opzione sorting (uploaded_at_asc, uploaded_at_desc, recorded_at_asc, recorded_at_desc, 
              name_asc, name_desc, player_asc, player_desc, training_type_asc, training_type_desc, 
              team_asc, team_desc, size_asc, size_desc)
        status: Filtro per status (opzionale)
        recorded_date_from: Filtro data realizzazione da (opzionale)
        recorded_date_to: Filtro data realizzazione a (opzionale)
        recorded_month: Filtro per mese (1-12, opzionale)
        recorded_year: Filtro per anno (opzionale)
        player_ids: Filtro per giocatori (comma-separated IDs, opzionale)
        training_type_ids: Filtro per tipi allenamento (comma-separated IDs, opzionale)
        team_ids: Filtro per squadre (comma-separated IDs, opzionale)
        db: Database session
        
    Returns:
        VideoListResponse con lista video paginata
        
    Raises:
        HTTPException: 400 se parametri invalidi
    """
    # Query base
    query = db.query(Video)
    
    # Filtro status
    if status:
        query = query.filter(Video.status == status)
    
    # Filtri per data realizzazione
    # Le date arrivano normalizzate con 12:00:00 UTC per evitare problemi di fuso orario
    if recorded_date_from:
        # Usa la data normalizzata (12:00:00) come riferimento
        # Filtra tutti i video dal giorno selezionato (>= 00:00:00 del giorno)
        from_date = datetime(
            recorded_date_from.year, 
            recorded_date_from.month, 
            recorded_date_from.day, 
            0, 0, 0
        )
        query = query.filter(Video.recorded_date >= from_date)
        
        # Se recorded_date_to è None o è lo stesso giorno di recorded_date_from, 
        # filtra solo quel giorno specifico (<= 23:59:59.999999 del giorno)
        if recorded_date_to is None or (
            recorded_date_to.year == recorded_date_from.year and
            recorded_date_to.month == recorded_date_from.month and
            recorded_date_to.day == recorded_date_from.day
        ):
            # Singolo giorno: filtra solo quel giorno
            to_date = datetime(
                recorded_date_from.year, 
                recorded_date_from.month, 
                recorded_date_from.day, 
                23, 59, 59, 999999
            )
            query = query.filter(Video.recorded_date <= to_date)
        elif recorded_date_to:
            # Periodo: recorded_date_to è diverso da recorded_date_from
            # Filtra fino alla fine del giorno 'to'
            to_date = datetime(
                recorded_date_to.year, 
                recorded_date_to.month, 
                recorded_date_to.day, 
                23, 59, 59, 999999
            )
            query = query.filter(Video.recorded_date <= to_date)
    elif recorded_date_to:
        # Se recorded_date_from è None, usa solo recorded_date_to
        to_date = datetime(
            recorded_date_to.year, 
            recorded_date_to.month, 
            recorded_date_to.day, 
            23, 59, 59, 999999
        )
        query = query.filter(Video.recorded_date <= to_date)
    if recorded_month and recorded_year:
        # Filtro per mese specifico
        from datetime import date
        start_date = date(recorded_year, recorded_month, 1)
        if recorded_month == 12:
            end_date = date(recorded_year + 1, 1, 1)
        else:
            end_date = date(recorded_year, recorded_month + 1, 1)
        query = query.filter(
            and_(
                Video.recorded_date >= start_date,
                Video.recorded_date < end_date
            )
        )
    elif recorded_year:
        # Filtro per anno
        from datetime import date
        start_date = date(recorded_year, 1, 1)
        end_date = date(recorded_year + 1, 1, 1)
        query = query.filter(
            and_(
                Video.recorded_date >= start_date,
                Video.recorded_date < end_date
            )
        )
    
    # Filtri per entità (player_ids, training_type_ids, team_ids)
    if player_ids:
        player_id_list = [pid.strip() for pid in player_ids.split(",") if pid.strip()]
        if player_id_list:
            # Video che hanno almeno uno dei giocatori selezionati
            video_ids_with_players = db.query(VideoPlayer.video_id).filter(
                VideoPlayer.player_id.in_(player_id_list)
            ).distinct().subquery()
            query = query.filter(Video.id.in_(db.query(video_ids_with_players.c.video_id)))
    
    if training_type_ids:
        training_type_id_list = [tid.strip() for tid in training_type_ids.split(",") if tid.strip()]
        if training_type_id_list:
            video_ids_with_training_types = db.query(VideoTrainingType.video_id).filter(
                VideoTrainingType.training_type_id.in_(training_type_id_list)
            ).distinct().subquery()
            query = query.filter(Video.id.in_(db.query(video_ids_with_training_types.c.video_id)))
    
    if team_ids:
        team_id_list = [tid.strip() for tid in team_ids.split(",") if tid.strip()]
        if team_id_list:
            video_ids_with_teams = db.query(VideoTeam.video_id).filter(
                VideoTeam.team_id.in_(team_id_list)
            ).distinct().subquery()
            query = query.filter(Video.id.in_(db.query(video_ids_with_teams.c.video_id)))
    
    # Ricerca avanzata
    if search:
        search_pattern = f"%{search}%"
        search_conditions = [
            Video.title.ilike(search_pattern),
            Video.filename.ilike(search_pattern),
        ]
        
        # Ricerca nei giocatori
        player_ids_matching = db.query(Player.id).filter(
            Player.name.ilike(search_pattern)
        ).subquery()
        video_ids_with_matching_players = db.query(VideoPlayer.video_id).filter(
            VideoPlayer.player_id.in_(db.query(player_ids_matching.c.id))
        ).distinct().subquery()
        search_conditions.append(Video.id.in_(db.query(video_ids_with_matching_players.c.video_id)))
        
        # Ricerca nei training types
        training_type_ids_matching = db.query(TrainingType.id).filter(
            TrainingType.name.ilike(search_pattern)
        ).subquery()
        video_ids_with_matching_training_types = db.query(VideoTrainingType.video_id).filter(
            VideoTrainingType.training_type_id.in_(db.query(training_type_ids_matching.c.id))
        ).distinct().subquery()
        search_conditions.append(Video.id.in_(db.query(video_ids_with_matching_training_types.c.video_id)))
        
        # Ricerca nelle squadre
        team_ids_matching = db.query(Team.id).filter(
            Team.name.ilike(search_pattern)
        ).subquery()
        video_ids_with_matching_teams = db.query(VideoTeam.video_id).filter(
            VideoTeam.team_id.in_(db.query(team_ids_matching.c.id))
        ).distinct().subquery()
        search_conditions.append(Video.id.in_(db.query(video_ids_with_matching_teams.c.video_id)))
        
        # Ricerca per anno (nella data realizzazione)
        try:
            year = int(search.strip())
            from datetime import date
            start_date = date(year, 1, 1)
            end_date = date(year + 1, 1, 1)
            search_conditions.append(
                and_(
                    Video.recorded_date >= start_date,
                    Video.recorded_date < end_date
                )
            )
        except ValueError:
            pass  # Non è un numero, ignora
        
        query = query.filter(or_(*search_conditions))
    
    # Sorting avanzato
    sort_mapping = {
        "uploaded_at_asc": asc(Video.created_at),
        "uploaded_at_desc": desc(Video.created_at),
        "recorded_at_asc": asc(Video.recorded_date),
        "recorded_at_desc": desc(Video.recorded_date),
        "name_asc": asc(Video.title),
        "name_desc": desc(Video.title),
        "size_asc": asc(Video.file_size),
        "size_desc": desc(Video.file_size),
        # Per compatibilità con vecchi valori
        "date_asc": asc(Video.created_at),
        "date_desc": desc(Video.created_at),
    }
    
    # Sorting per player, training_type, team richiede join
    # Per ora usiamo un approccio semplificato: ordinamento per nome video se non specificato
    sort_column = sort_mapping.get(sort, desc(Video.created_at))
    query = query.order_by(sort_column)
    
    # Conteggio totale coerente con i filtri applicati
    total = query.count()

    # Paginazione
    offset = (page - 1) * limit
    videos = query.offset(offset).limit(limit).all()

    # Converti a VideoListItem (operazione idempotente di sola lettura: nessuna mutazione o cancellazione DB)
    items = [
        VideoListItem(
            id=video.id,
            title=video.title,
            filename=video.filename,
            file_size=video.file_size,
            duration=video.duration,
            width=video.width,
            height=video.height,
            thumbnail_url=f"/api/videos/{video.id}/thumbnail" if video.thumbnail_path else None,
            status=video.status,
            created_at=video.created_at,
        )
        for video in videos
    ]

    return VideoListResponse(
        items=items,
        total=total,
        page=page,
        limit=limit,
    )


@router.put("/api/videos/{video_id}", response_model=VideoResponse)
async def update_video(
    video_id: str,
    title: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    recorded_date: Optional[str] = Form(None),  # Riceviamo come stringa ISO e facciamo parsing
    db: Session = Depends(get_db),
):
    """Aggiorna video (titolo, descrizione, data realizzazione).
    
    Args:
        video_id: ID video da aggiornare
        title: Nuovo titolo (max 255 caratteri, opzionale)
        description: Nuova descrizione (opzionale)
        recorded_date: Nuova data realizzazione (opzionale)
        db: Database session
        
    Returns:
        VideoResponse: Video aggiornato
        
    Raises:
        HTTPException: 404 se video non trovato
        HTTPException: 400 se titolo invalido (vuoto o troppo lungo)
    """
    video = db.query(Video).filter(Video.id == video_id).first()
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")
    
    # Aggiorna campi se forniti
    if title is not None:
        if not title.strip():
            raise HTTPException(status_code=400, detail="Title cannot be empty")
        if len(title) > 255:
            raise HTTPException(status_code=400, detail="Title too long (max 255 characters)")
        video.title = title.strip()
    
    if description is not None:
        video.description = description.strip() if description else None
    
    if recorded_date is not None:
        # Parse ISO string to datetime, or set to None if empty string
        recorded_date_clean = recorded_date.strip() if isinstance(recorded_date, str) else str(recorded_date)
        
        if not recorded_date_clean or recorded_date_clean.lower() in ('null', 'none', ''):
            video.recorded_date = None
        else:
            try:
                # Normalizza sempre con 12:00:00 UTC per evitare problemi di fuso orario
                # Handle various ISO formats: 2024-12-01T18:25:30.123Z, 2024-12-01T18:25:30Z, 2024-12-01
                date_str = recorded_date_clean.replace('Z', '').replace('+00:00', '')
                
                # Remove milliseconds if present (e.g., .123)
                if '.' in date_str and 'T' in date_str:
                    date_str = date_str.split('.')[0]
                
                # Try parsing with fromisoformat (Python 3.7+)
                if 'T' in date_str:
                    # ISO format with time (YYYY-MM-DDTHH:MM:SS)
                    # Ensure we have a complete datetime string
                    parts = date_str.split('T')
                    if len(parts) == 2:
                        date_part = parts[0]
                        time_part = parts[1]
                        # Ensure time part has at least HH:MM:SS
                        time_parts = time_part.split(':')
                        if len(time_parts) < 3:
                            time_part = ':'.join(time_parts + ['00'] * (3 - len(time_parts)))
                        date_str = f"{date_part}T{time_part}"
                    parsed_dt = datetime.fromisoformat(date_str)
                    # Normalizza con 12:00:00 per evitare problemi di fuso orario
                    video.recorded_date = datetime(
                        parsed_dt.year, 
                        parsed_dt.month, 
                        parsed_dt.day, 
                        12, 0, 0
                    )
                else:
                    # Date only format (YYYY-MM-DD)
                    from datetime import date as date_type
                    parsed_date = date_type.fromisoformat(date_str)
                    # Normalizza con 12:00:00 per evitare problemi di fuso orario
                    video.recorded_date = datetime(
                        parsed_date.year, 
                        parsed_date.month, 
                        parsed_date.day, 
                        12, 0, 0
                    )
            except (ValueError, AttributeError) as e:
                import logging
                logger = logging.getLogger(__name__)
                logger.error(f"Error parsing recorded_date: {recorded_date_clean}, error: {e}")
                raise HTTPException(
                    status_code=400, 
                    detail=f"Invalid recorded_date format: '{recorded_date_clean}'. Expected ISO format (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS). Error: {str(e)}"
                )
    
    db.commit()
    db.refresh(video)
    
    return VideoResponse.model_validate(video)


@router.get("/api/videos/{video_id}", response_model=VideoResponse)
async def get_video(
    video_id: str,
    db: Session = Depends(get_db),
):
    """Dettagli video singolo.
    
    Args:
        video_id: ID video (UUID)
        db: Database session
        
    Returns:
        VideoResponse con dettagli completi video
        
    Raises:
        HTTPException: 404 se video non trovato
    """
    video = db.query(Video).filter(Video.id == video_id).first()
    
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")
    
    # Carica associazioni (player_ids, training_type_ids, team_ids)
    player_ids = [vp.player_id for vp in db.query(VideoPlayer).filter(VideoPlayer.video_id == video_id).all()]
    training_type_ids = [vtt.training_type_id for vtt in db.query(VideoTrainingType).filter(VideoTrainingType.video_id == video_id).all()]
    team_ids = [vt.team_id for vt in db.query(VideoTeam).filter(VideoTeam.video_id == video_id).all()]
    
    # Crea dict con tutti i dati
    video_dict = {
        **{c.name: getattr(video, c.name) for c in video.__table__.columns},
        'player_ids': player_ids if player_ids else None,
        'training_type_ids': training_type_ids if training_type_ids else None,
        'team_ids': team_ids if team_ids else None,
    }
    
    return VideoResponse.model_validate(video_dict)


@router.get("/api/videos/{video_id}/thumbnail")
async def get_video_thumbnail(
    video_id: str,
    db: Session = Depends(get_db),
):
    """Thumbnail video.
    
    Args:
        video_id: ID video (UUID)
        db: Database session
        
    Returns:
        FileResponse con immagine thumbnail
        
    Raises:
        HTTPException: 404 se video o thumbnail non trovato
    """
    video = db.query(Video).filter(Video.id == video_id).first()
    
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")
    
    if not video.thumbnail_path:
        # Usa thumbnail default se non disponibile
        default_thumbnail = Path(settings.DEFAULT_THUMBNAIL_PATH)
        if default_thumbnail.exists():
            return FileResponse(
                str(default_thumbnail),
                media_type="image/jpeg",
            )
        raise HTTPException(status_code=404, detail="Thumbnail not found")
    
    thumbnail_path = Path(video.thumbnail_path)
    if not thumbnail_path.exists():
        raise HTTPException(status_code=404, detail="Thumbnail not found")
    
    return FileResponse(
        str(thumbnail_path),
        media_type="image/jpeg",
    )


@router.delete("/api/videos/{video_id}", status_code=204)
async def delete_video(
    video_id: str,
    db: Session = Depends(get_db),
):
    """Elimina video dal server.
    
    Elimina:
    - File video dal disco
    - Thumbnail se esiste
    - Tutte le associazioni (giocatori, training types, squadre, note)
    - Record dal database
    
    Args:
        video_id: ID video da eliminare
        db: Database session
        
    Returns:
        None (status 204 No Content)
        
    Raises:
        HTTPException: 404 se video non trovato
        HTTPException: 500 se errore durante eliminazione
    """
    video_service = VideoService(db)
    video_service.delete_video(video_id)
    return None


@router.get("/api/videos/{video_id}/stream")
async def stream_video(
    video_id: str,
    request: Request,
    db: Session = Depends(get_db),
    range: Optional[str] = Header(None),
):
    """Stream video con supporto Range requests (HTTP 206).
    
    Supporta HTTP Range requests per streaming efficiente:
    - Client può richiedere porzioni specifiche del file
    - Server risponde con HTTP 206 (Partial Content)
    - Headers: Content-Range, Accept-Ranges, Content-Length
    
    Args:
        video_id: ID video (UUID)
        request: FastAPI Request object
        db: Database session
        range: Range header (es: "bytes=0-1023")
        
    Returns:
        StreamingResponse con video file o porzione richiesta
        
    Raises:
        HTTPException: 404 se video o file non trovato
        HTTPException: 416 se range invalido
    """
    # Verifica video esiste
    video = db.query(Video).filter(Video.id == video_id).first()
    
    if not video:
        raise HTTPException(
            status_code=404, 
            detail=f"Video not found with id: {video_id}"
        )
    
    if video.status != "ready":
        raise HTTPException(
            status_code=400, 
            detail=f"Video not ready for streaming (status: {video.status})"
        )
    
    # Verifica file esiste
    # file_path nel database può essere:
    # - Assoluto: "/path/to/file.mp4"
    # - Relativo: "storage/videos/file.mp4" o solo "file.mp4"
    # Strategia: sempre estrarre solo il filename e costruire relativamente a VIDEOS_PATH
    # Questo evita problemi con path relativi diversi
    video_path = Path(video.file_path)
    
    # Normalizza VIDEOS_PATH (risolvi path relativo)
    videos_path = Path(settings.VIDEOS_PATH).resolve()
    
    # Se il path non è assoluto, costruisci relativamente a VIDEOS_PATH
    if not video_path.is_absolute():
        # Sempre estrai solo il filename e costruisci relativamente a VIDEOS_PATH
        # Questo evita duplicazioni e problemi con path relativi
        video_path = videos_path / video_path.name
    # Se è assoluto, verifica che esista
    elif not video_path.exists():
        # Se path assoluto non esiste, prova a costruirlo relativamente a VIDEOS_PATH
        video_path = videos_path / Path(video.file_path).name
    
    # Verifica file esiste
    if not video_path.exists():
        # Log per debugging
        import logging
        logger = logging.getLogger(__name__)
        logger.error(
            f"Video file not found: video_id={video_id}, "
            f"video_title={video.title}, "
            f"file_path={video.file_path}, "
            f"resolved_path={video_path}, "
            f"resolved_path_absolute={video_path.resolve()}, "
            f"VIDEOS_PATH={settings.VIDEOS_PATH}, "
            f"VIDEOS_PATH_resolved={videos_path}, "
            f"VIDEOS_PATH_exists={videos_path.exists()}, "
            f"cwd={Path.cwd()}"
        )
        raise HTTPException(
            status_code=404, 
            detail=f"Video file not found. Path: {video_path}"
        )
    
    # Ottieni dimensione file
    file_size = video_path.stat().st_size
    
    # Determina media type basato su estensione
    # IMPORTANTE: Per ExoPlayer su Android, usa sempre video/mp4 per MP4 files
    # Alcuni codec potrebbero non essere supportati, quindi assicurati che i video siano in formato compatibile
    media_type_map = {
        ".mp4": "video/mp4",  # ExoPlayer supporta MP4 con codec H.264/AAC
        ".avi": "video/x-msvideo",
        ".mov": "video/quicktime",
        ".mkv": "video/x-matroska",
        ".webm": "video/webm",
    }
    media_type = media_type_map.get(video_path.suffix.lower(), "video/mp4")
    
    # Log per debug (solo in modalità debug)
    if settings.DEBUG:
        import logging
        logger = logging.getLogger(__name__)
        logger.info(f"Streaming video: id={video_id}, path={video_path}, media_type={media_type}, size={file_size}")
    
    # Headers base per tutte le risposte
    base_headers = {
        "Accept-Ranges": "bytes",
        "Content-Type": media_type,
        "Cache-Control": "public, max-age=3600",
    }
    
    # Se non c'è Range header, restituisci file completo
    if not range:
        return FileResponse(
            str(video_path),
            media_type=media_type,
            headers={
                **base_headers,
                "Content-Length": str(file_size),
            },
        )
    
    # Parse Range header (es: "bytes=0-1023" o "bytes=1024-")
    try:
        range_match = range.replace("bytes=", "")
        start, end = range_match.split("-")
        start = int(start) if start else 0
        end = int(end) if end else file_size - 1
    except (ValueError, AttributeError):
        raise HTTPException(status_code=416, detail="Invalid Range header")
    
    # Valida range
    if start < 0 or end >= file_size or start > end:
        raise HTTPException(
            status_code=416,
            detail=f"Range not satisfiable. File size: {file_size}",
            headers={"Content-Range": f"bytes */{file_size}"},
        )
    
    # Calcola dimensione chunk
    chunk_size = end - start + 1
    
    # Funzione generator per streaming chunk
    async def generate_chunk():
        with open(video_path, "rb") as f:
            f.seek(start)
            remaining = chunk_size
            while remaining > 0:
                chunk = f.read(min(8192, remaining))  # Leggi 8KB alla volta
                if not chunk:
                    break
                remaining -= len(chunk)
                yield chunk
    
    # Headers per Range response
    headers = {
        **base_headers,
        "Content-Range": f"bytes {start}-{end}/{file_size}",
        "Content-Length": str(chunk_size),
    }
    
    return StreamingResponse(
        generate_chunk(),
        status_code=206,  # Partial Content
        headers=headers,
        media_type=media_type,
    )
