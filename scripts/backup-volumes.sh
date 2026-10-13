#!/usr/bin/env bash
# ==============================================================================
# backup-volumes.sh - Automated Daily Backup for Homelab Docker Volumes & DBs
# ==============================================================================
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/opt/homelab/backups}"
DATA_DIR="${DATA_DIR:-/opt/homelab/data}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_ARCHIVE="${BACKUP_DIR}/homelab_backup_${TIMESTAMP}.tar.gz"
RETENTION_DAYS=7

mkdir -p "$BACKUP_DIR"

echo "[+] Starting homelab backup at $(date)..."

# 1. Safely backup SQLite databases (Vaultwarden, Football Manager) using sqlite3 .backup if present
if command -v sqlite3 >/dev/null 2>&1; then
    if [ -f "${DATA_DIR}/vaultwarden/db.sqlite3" ]; then
        echo "[*] Creating consistent SQLite backup for Vaultwarden..."
        sqlite3 "${DATA_DIR}/vaultwarden/db.sqlite3" ".backup '${DATA_DIR}/vaultwarden/db_backup.sqlite3'"
    fi
fi

# 2. Archive all data volumes excluding ephemeral caches
echo "[+] Creating compressed tarball: ${BACKUP_ARCHIVE}..."
tar -czf "$BACKUP_ARCHIVE" \
    --exclude='*/tmp/*' \
    --exclude='*/cache/*' \
    -C "$DATA_DIR" .

echo "[+] Backup created: $(du -sh "$BACKUP_ARCHIVE" | awk '{print $1}')"

# 3. Clean up backups older than RETENTION_DAYS
echo "[+] Pruning backups older than ${RETENTION_DAYS} days..."
find "$BACKUP_DIR" -name "homelab_backup_*.tar.gz" -type f -mtime +"$RETENTION_DAYS" -delete

echo "[✓] Backup completed successfully at $(date)!"
