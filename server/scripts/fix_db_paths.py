"""
fix_db_paths.py
───────────────
Script ONE-SHOT: converte i path Windows assoluti nel DB SQLite
in path Linux assoluti dentro il container Docker.

Eseguire UNA SOLA VOLTA dopo aver copiato il DB sul server Linux,
prima di avviare il container.

Uso:
    python scripts/fix_db_paths.py [--db /path/to/videos.db] [--dry-run]

Esempi:
    # Anteprima (non modifica nulla)
    python scripts/fix_db_paths.py --dry-run

    # Applica fix
    python scripts/fix_db_paths.py

    # DB in path custom
    python scripts/fix_db_paths.py --db /opt/myteam/data/videos.db
"""

import sqlite3
import shutil
import argparse
import re
from pathlib import Path
from datetime import datetime

# ─── Configurazione path ────────────────────────────────────────────────────
# Prefisso Windows da sostituire (case-insensitive)
WIN_STORAGE_PREFIX = re.compile(
    r"(?i)[A-Z]:\\Users\\[^\\]+\\Documents\\MyTeam\\server\\storage(?=\\|$)",
)
# Path Linux dentro il container
LINUX_STORAGE_PREFIX = "/app/storage"

# Pattern aggiuntivo per eventuali slash forward su Windows
WIN_STORAGE_PREFIX_FWD = re.compile(
    r"(?i)[A-Z]:/Users/[^/]+/Documents/MyTeam/server/storage(?=/|$)",
)
# ────────────────────────────────────────────────────────────────────────────


def fix_path(path: str | None) -> str | None:
    """Converte un path Windows in path Linux."""
    if not path:
        return path
    result = WIN_STORAGE_PREFIX.sub(LINUX_STORAGE_PREFIX, path)
    result = WIN_STORAGE_PREFIX_FWD.sub(LINUX_STORAGE_PREFIX, result)
    # Normalizza backslash residui
    result = result.replace("\\", "/")
    return result


def main():
    parser = argparse.ArgumentParser(description="Fix Windows paths in SQLite DB")
    parser.add_argument("--db", default="./videos.db", help="Path al file videos.db")
    parser.add_argument("--dry-run", action="store_true",
                        help="Mostra le modifiche senza applicarle")
    args = parser.parse_args()

    db_path = Path(args.db).resolve()
    if not db_path.exists():
        print("[ERROR] Database file not found.")
        exit(1)

    # Backup automatico prima di modificare
    if not args.dry_run:
        backup_path = db_path.with_suffix(
            f".backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.db"
        )
        shutil.copy2(db_path, backup_path)
        print("[BACKUP] Database backup created.")

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row

    try:
        cursor = conn.cursor()

        # ── Tabella videos: file_path e thumbnail_path ──────────────────────
        cursor.execute("SELECT id, file_path, thumbnail_path FROM videos")
        rows = cursor.fetchall()

        updated = 0
        for row in rows:
            new_file_path = fix_path(row["file_path"])
            new_thumb_path = fix_path(row["thumbnail_path"])

            changed = (
                new_file_path != row["file_path"] or
                new_thumb_path != row["thumbnail_path"]
            )

            if changed:
                print("[UPDATE] A stored media path will be normalized.")

                if not args.dry_run:
                    cursor.execute(
                        "UPDATE videos SET file_path=?, thumbnail_path=? WHERE id=?",
                        (new_file_path, new_thumb_path, row["id"])
                    )
                    updated += 1

        # ── Commit ──────────────────────────────────────────────────────────
        if not args.dry_run:
            conn.commit()
            print(f"\n[OK] Aggiornati {updated} record su {len(rows)} totali.")
        else:
            print(f"\n[DRY-RUN] {sum(1 for r in rows if fix_path(r['file_path']) != r['file_path'])} record da aggiornare (nessuna modifica applicata).")

    finally:
        conn.close()


if __name__ == "__main__":
    main()
