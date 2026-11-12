"""Migration script to add recorded_date column to videos table"""
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import text
from app.core.database import engine
from app.core.config import get_settings

settings = get_settings()


def migrate():
    """Add recorded_date column to videos table if it doesn't exist"""
    print("Starting migration: Add recorded_date column to videos table...")
    
    with engine.connect() as conn:
        # Check if column exists (SQLite specific)
        if "sqlite" in settings.DATABASE_URL:
            # Get table info
            result = conn.execute(text("PRAGMA table_info(videos)"))
            columns = [row[1] for row in result]
            
            if "recorded_date" not in columns:
                print("Adding recorded_date column to videos table...")
                conn.execute(text("ALTER TABLE videos ADD COLUMN recorded_date DATETIME"))
                conn.commit()
                print("✓ Column recorded_date added successfully")
            else:
                print("✓ Column recorded_date already exists")
        else:
            # PostgreSQL/MySQL - check if column exists
            try:
                result = conn.execute(text("""
                    SELECT column_name 
                    FROM information_schema.columns 
                    WHERE table_name='videos' AND column_name='recorded_date'
                """))
                if result.fetchone() is None:
                    print("Adding recorded_date column to videos table...")
                    conn.execute(text("ALTER TABLE videos ADD COLUMN recorded_date TIMESTAMP"))
                    conn.commit()
                    print("✓ Column recorded_date added successfully")
                else:
                    print("✓ Column recorded_date already exists")
            except Exception as e:
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
                        print("Adding recorded_date column to videos table...")
                        conn.execute(text("ALTER TABLE videos ADD COLUMN recorded_date DATETIME"))
                        conn.commit()
                        print("✓ Column recorded_date added successfully")
                    else:
                        print("✓ Column recorded_date already exists")
                except Exception as e2:
                    print(f"Error checking/adding column: {e2}")
                    raise
    
    print("Migration completed!")


if __name__ == "__main__":
    migrate()

