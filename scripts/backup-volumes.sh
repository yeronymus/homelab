#!/usr/bin/env bash
# ==============================================================================
# backup-volumes.sh - Automated Backup for Homelab Volumes & Bot Databases
# ==============================================================================
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/opt/homelab/backups}"
DATA_DIR="${DATA_DIR:-/opt/homelab/data}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_ARCHIVE="${BACKUP_DIR}/homelab_backup_${TIMESTAMP}.tar.gz"
PG_BACKUP_FILE="${BACKUP_DIR}/football_bot_db_${TIMESTAMP}.sql.gz"
RETENTION_DAYS=7

mkdir -p "$BACKUP_DIR"

echo "[+] Starting homelab backup at $(date)..."

# 1. Safely backup Football Manager PostgreSQL database if container is running
if docker ps --format '{{.Names}}' | grep -q "^football-manager-db-1$"; then
    echo "[*] Creating hot PostgreSQL dump for football-manager..."
    if docker exec football-manager-db-1 pg_dump -U postgres football_debug | gzip > "$PG_BACKUP_FILE"; then
        echo "[+] Football Manager DB backup saved: $(du -sh "$PG_BACKUP_FILE" | awk '{print $1}')"
    else
        echo "[!] Warning: PostgreSQL dump failed, continuing with volume backups..."
    fi
fi

# 2. Safely backup SQLite databases (Vaultwarden) using sqlite3 .backup if present
if command -v sqlite3 >/dev/null 2>&1; then
    if [ -f "${DATA_DIR}/vaultwarden/db.sqlite3" ]; then
        echo "[*] Creating consistent SQLite backup for Vaultwarden..."
        sqlite3 "${DATA_DIR}/vaultwarden/db.sqlite3" ".backup '${DATA_DIR}/vaultwarden/db_backup.sqlite3'"
    fi
fi

# 3. Archive all data volumes excluding ephemeral caches
echo "[+] Creating compressed tarball of volumes: ${BACKUP_ARCHIVE}..."
tar -czf "$BACKUP_ARCHIVE" \
    --exclude='*/tmp/*' \
    --exclude='*/cache/*' \
    -C "$DATA_DIR" .

echo "[+] Homelab volumes backup created: $(du -sh "$BACKUP_ARCHIVE" | awk '{print $1}')"

# 4. Clean up backups older than RETENTION_DAYS
echo "[+] Pruning backups older than ${RETENTION_DAYS} days..."
find "$BACKUP_DIR" -name "homelab_backup_*.tar.gz" -type f -mtime +"$RETENTION_DAYS" -delete
find "$BACKUP_DIR" -name "football_bot_db_*.sql.gz" -type f -mtime +"$RETENTION_DAYS" -delete

echo "[✓] All backups completed successfully at $(date)!"
