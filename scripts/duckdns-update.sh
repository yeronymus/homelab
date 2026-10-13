#!/usr/bin/env bash
# ==============================================================================
# duckdns-update.sh - Lightweight Dynamic DNS Updater for DuckDNS
# ==============================================================================
set -euo pipefail

DUCKDNS_DOMAIN="${DUCKDNS_DOMAIN:-}"
DUCKDNS_TOKEN="${DUCKDNS_TOKEN:-}"

if [ -z "$DUCKDNS_DOMAIN" ] || [ -z "$DUCKDNS_TOKEN" ]; then
    echo "[-] Error: DUCKDNS_DOMAIN and DUCKDNS_TOKEN must be set." >&2
    exit 1
fi

RESPONSE=$(curl -s --connect-timeout 10 --max-time 30 \
    "https://www.duckdns.org/update?domains=${DUCKDNS_DOMAIN}&token=${DUCKDNS_TOKEN}&ip=")

if [ "$RESPONSE" = "OK" ]; then
    echo "[$(date)] DuckDNS IP successfully updated for ${DUCKDNS_DOMAIN}"
else
    echo "[$(date)] DuckDNS update returned: ${RESPONSE}" >&2
    exit 1
fi
