#!/usr/bin/env bash
# ==============================================================================
# generate-self-signed-ssl.sh - Create initial self-signed SSL certs for Nginx
# ==============================================================================
set -euo pipefail

SSL_DIR="./ssl/live"
mkdir -p "$SSL_DIR"

if [ -f "${SSL_DIR}/fullchain.pem" ] && [ -f "${SSL_DIR}/privkey.pem" ]; then
    echo "[*] SSL certificates already exist in ${SSL_DIR}."
    exit 0
fi

echo "[+] Generating placeholder self-signed SSL certificate for Nginx startup..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "${SSL_DIR}/privkey.pem" \
    -out "${SSL_DIR}/fullchain.pem" \
    -subj "/C=US/ST=State/L=City/O=Homelab/CN=homelab.local"

chmod 600 "${SSL_DIR}/privkey.pem"
chmod 644 "${SSL_DIR}/fullchain.pem"

echo "[✓] Placeholder SSL certificate created successfully in ${SSL_DIR}."
echo "[TIP] You can now obtain real Let's Encrypt certificates using Certbot or Cloudflare Tunnel."
