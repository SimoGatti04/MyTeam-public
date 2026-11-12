"""FastAPI application entry point"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import get_settings, init_storage_directories
from app.core.database import init_db

# Get settings
settings = get_settings()

# Initialize storage directories
init_storage_directories(settings)

# Create FastAPI app
app = FastAPI(
    title="MyTeam Video Server",
    description="Self-hosted video management server",
    version="0.1.0",
    debug=settings.DEBUG
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS.split(",") if settings.CORS_ORIGINS != "*" else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup_event():
    """Initialize database and verify dependencies on startup"""
    init_db()
    
    # Run migrations - add recorded_date column if missing
    try:
        from sqlalchemy import text
        from app.core.database import engine
        
        with engine.connect() as conn:
            # Check if column exists (SQLite specific)
            if "sqlite" in settings.DATABASE_URL:
                result = conn.execute(text("PRAGMA table_info(videos)"))
                columns = [row[1] for row in result]
                
                if "recorded_date" not in columns:
                    print("[MIGRATION] Adding recorded_date column to videos table...")
                    conn.execute(text("ALTER TABLE videos ADD COLUMN recorded_date DATETIME"))
                    conn.commit()
                    print("[OK] Migration: recorded_date column added")
            else:
                # PostgreSQL/MySQL
                try:
                    result = conn.execute(text("""
                        SELECT column_name 
                        FROM information_schema.columns 
                        WHERE table_name='videos' AND column_name='recorded_date'
                    """))
                    if result.fetchone() is None:
                        print("[MIGRATION] Adding recorded_date column to videos table...")
                        conn.execute(text("ALTER TABLE videos ADD COLUMN recorded_date TIMESTAMP"))
                        conn.commit()
                        print("[OK] Migration: recorded_date column added")
                except Exception:
                    # Try MySQL syntax
                    try:
                        result = conn.execute(text("""
                            SELECT column_name 
                            FROM information_schema.columns 
                            WHERE table_schema = DATABASE() 
                            AND table_name='videos' 
                            AND column_name='recorded_date'
                        """))
                        if result.fetchone() is None:
                            print("[MIGRATION] Adding recorded_date column to videos table...")
                            conn.execute(text("ALTER TABLE videos ADD COLUMN recorded_date DATETIME"))
                            conn.commit()
                            print("[OK] Migration: recorded_date column added")
                    except Exception as e:
                        print(f"[WARNING] Could not add recorded_date column: {e}")
    except Exception as e:
        print(f"[WARNING] Migration error (may be harmless): {e}")
    
    print("[OK] Database initialized")
    
    # Verifica FFmpeg/FFprobe
    from app.core.ffmpeg_verification import verify_ffmpeg_installation
    try:
        verify_ffmpeg_installation()
        print("[OK] FFmpeg/FFprobe verified")
    except RuntimeError as e:
        print(f"[WARNING] {str(e)}")
        print("[WARNING] Server funzionerà ma metadata extraction e thumbnail generation falliranno")
    
    print("[OK] Storage directories initialized")


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "MyTeam Video Server",
        "version": "0.1.0",
        "status": "running"
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}


# Import routes
from app.api.routes import videos, chunked_upload, players, training_types, teams, notes

# Register routes
app.include_router(videos.router, tags=["videos"])
app.include_router(chunked_upload.router, tags=["chunked-upload"])
app.include_router(players.router, tags=["players"])
app.include_router(training_types.router, tags=["training-types"])
app.include_router(teams.router, tags=["teams"])
app.include_router(notes.router, tags=["notes"])


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=settings.SERVER_HOST,
        port=settings.SERVER_PORT,
        reload=settings.DEBUG
    )

