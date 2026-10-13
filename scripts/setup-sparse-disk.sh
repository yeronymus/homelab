#!/usr/bin/env bash
# ==============================================================================
# setup-sparse-disk.sh - Virtual 1TB HDD Provisioner using Sparse Loop Device
# ==============================================================================
# This script creates a virtual 1 TB disk backed by a sparse image file on the SSD.
# A sparse file consumes ZERO actual disk space initially and grows only as real
# data is written into it. This allows running the full homelab setup immediately
# without waiting for physical 1 TB HDD installation.
#
# When you later add the real physical HDD, simply copy data over and mount the
# physical partition to /mnt/hdd without touching Docker Compose or any configs!
# ==============================================================================

set -euo pipefail

IMAGE_DIR="/var/lib/homelab"
IMAGE_FILE="${IMAGE_DIR}/virtual-hdd.img"
MOUNT_POINT="/mnt/hdd"
VIRTUAL_SIZE="1000G"

echo "=========================================================="
echo " Homelab Virtual 1TB HDD Setup (Sparse Loopback Device)"
echo "=========================================================="

if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Error: This script must be run as root (or with sudo)." >&2
    exit 1
fi

# Check if already mounted
if mountpoint -q "$MOUNT_POINT"; then
    echo "[!] Target ${MOUNT_POINT} is already mounted. Nothing to do."
    df -h "$MOUNT_POINT"
    exit 0
fi

# 1. Create directory for virtual disk
mkdir -p "$IMAGE_DIR"
mkdir -p "$MOUNT_POINT"

# 2. Create sparse file if it doesn't already exist
if [ ! -f "$IMAGE_FILE" ]; then
    echo "[+] Creating ${VIRTUAL_SIZE} sparse disk image at ${IMAGE_FILE}..."
    truncate -s "$VIRTUAL_SIZE" "$IMAGE_FILE"
    
    echo "[+] Formatting sparse image with ext4 filesystem..."
    mkfs.ext4 -F -q -m 1 -L homelab-data "$IMAGE_FILE"
else
    echo "[*] Existing image found at ${IMAGE_FILE}, reusing it."
fi

# 3. Add to /etc/fstab for automatic mounting on boot
FSTAB_LINE="${IMAGE_FILE} ${MOUNT_POINT} ext4 loop,discard,defaults,nofail 0 2"
if ! grep -qF "$IMAGE_FILE" /etc/fstab; then
    echo "[+] Adding persistent mount to /etc/fstab..."
    echo "$FSTAB_LINE" >> /etc/fstab
else
    echo "[*] /etc/fstab entry already present."
fi

# 4. Mount filesystem
echo "[+] Mounting ${IMAGE_FILE} to ${MOUNT_POINT}..."
mount "$MOUNT_POINT"

# 5. Initialize homelab directory structure on the virtual disk
echo "[+] Initializing persistent service directories under ${MOUNT_POINT}/data..."
mkdir -p "${MOUNT_POINT}/data/vaultwarden"
mkdir -p "${MOUNT_POINT}/data/pihole/etc-pihole"
mkdir -p "${MOUNT_POINT}/data/pihole/etc-dnsmasq.d"
mkdir -p "${MOUNT_POINT}/data/uptime-kuma"
mkdir -p "${MOUNT_POINT}/data/prometheus"
mkdir -p "${MOUNT_POINT}/data/grafana"
mkdir -p "${MOUNT_POINT}/data/portainer"
mkdir -p "${MOUNT_POINT}/data/football-manager"
mkdir -p "${MOUNT_POINT}/backups"

# Set permissions for unprivileged containers
chmod 777 "${MOUNT_POINT}/data/grafana"
chmod 777 "${MOUNT_POINT}/data/prometheus"

echo ""
echo "[✓] Virtual 1TB HDD successfully created and mounted at ${MOUNT_POINT}!"
echo "----------------------------------------------------------"
df -h "$MOUNT_POINT"
echo "----------------------------------------------------------"
echo "[TIP] How to migrate when you install your real 1TB physical HDD:"
echo " 1. Format your physical drive (e.g. mkfs.ext4 /dev/sdb1)"
echo " 2. Mount it temporarily: mount /dev/sdb1 /mnt/new_hdd"
echo " 3. Copy files: rsync -aHAX --progress ${MOUNT_POINT}/ /mnt/new_hdd/"
echo " 4. Unmount both and replace the entry in /etc/fstab with:"
echo "    UUID=\$(blkid -s UUID -o value /dev/sdb1) ${MOUNT_POINT} ext4 defaults 0 2"
echo " 5. Remove ${IMAGE_FILE} to reclaim SSD space. No Docker changes required!"
echo "=========================================================="
