# Personal Homelab & Self-Hosted Infrastructure

A compact, single-node production homelab built on repurposed laptop hardware. Designed to host self-hosted daily utilities, provide secure credential management, serve internal DNS with network-wide ad blocking, run a webhook-based Telegram bot runtime, maintain system observability, and handle secure external ingress alongside encrypted remote administration.

## Quick Summary

* **Hardware:** HP Pavilion 14 (Intel Core i5-8265U 4C/8T, 8 GB RAM, 128 GB SSD).
* **Storage Policy:** Single-disk SSD deployment (`/opt/homelab/data`). The entire base OS and Docker container stack consume under 15 GB, leaving >100 GB of free SSD storage for fast SQLite databases and operational data without requiring secondary disks.
* **Base OS:** Debian 12 (Bookworm) Minimal (headless).
* **Ingress & Networking:** Public (White) IP synchronized via **DuckDNS**, automated **Let's Encrypt TLS**, and **Nginx Reverse Proxy**. Public ingress is strictly scoped to the Telegram bot webhook endpoint.
* **Network & DNS:** **Pi-hole** deployed as an internal DNS sinkhole for network-wide ad blocking and custom local domain resolution (`*.lab`).
* **Self-Hosted Productivity:** **Vaultwarden** (lightweight Bitwarden implementation) for encrypted personal secret and password management.
* **Remote Management:** **Tailscale (WireGuard Mesh)** deployed for encrypted administrative access (SSH, Homepage, Grafana, Portainer, Vaultwarden, Pi-hole) from authorized personal devices without exposing management ports to the internet.
* **Dashboard:** **Homepage** deployed as a unified, modern dashboard with live Docker container metrics, host CPU/RAM/disk widgets, and direct service shortcuts.
* **Extensibility:** Support for custom user applications and bots attached cleanly via Docker network.
* **Observability:** Prometheus + Grafana telemetry stack, local Uptime Kuma for service heartbeats, and an external Dead Man's Snitch ping for power and upstream connection outages.
* **Provisioning & Orchestration:** Fully automated via **Ansible** and **Docker Compose**.

---

## Table of Contents

1. [Hardware Specifications](#1-hardware-specifications)
2. [Storage Strategy (SSD Standalone)](#2-storage-strategy-ssd-standalone)
3. [Network Topology & Public IP Ingress](#3-network-topology--public-ip-ingress)
4. [Service Catalog](#4-service-catalog)
5. [Dashboard: Homepage](#5-dashboard-homepage)
6. [Core Self-Hosted Services](#6-core-self-hosted-services)
7. [Deploying Custom Applications & Bots](#7-deploying-custom-applications--bots)
8. [Observability & Alert Pipeline](#8-observability--alert-pipeline)
9. [Automated Deployment via Ansible](#9-automated-deployment-via-ansible)
10. [Manual Deployment via Docker Compose](#10-manual-deployment-via-docker-compose)
11. [Maintenance & Automation Scripts](#11-maintenance--automation-scripts)

---

## 1. Hardware Specifications

* **Host Machine:** HP Pavilion 14-ce1005ur
* **CPU:** Intel Core i5-8265U (4 cores / 8 threads, up to 3.90 GHz)
* **RAM:** 8 GB DDR4-2400 MHz
* **Storage:** 128 GB M.2 SATA SSD (OS, Docker images, SQLite databases, and application data)
* **Networking:** Realtek Gigabit Ethernet (RTL8111/8168/8411)
* **Power & Thermal Policy:**
  * Headless lid behavior managed via `systemd-logind` (`HandleLidSwitch=ignore`).
  * TLP deployed to control charge thresholds and reduce battery thermal wear under constant 24/7 AC power.
  * Laptop battery serves as an integrated Uninterruptible Power Supply (UPS) against brief power drops.

---

## 2. Storage Strategy (SSD Standalone)

Currently, the homelab runs **entirely on the 128 GB SSD**. Secondary heavy storage disks (such as a 1 TB HDD) are intentionally omitted for now.

### Storage Allocation Breakdown
* **Debian 12 Minimal OS:** ~3.5 GB
* **Docker Engine & Images:** ~6.0 GB
* **Persistent Container Data (`/opt/homelab/data`):** ~1.5 GB
* **Remaining Available Space:** **>100 GB**

Because resource-heavy storage consumers (such as Immich photo galleries, Nextcloud, or torrent seeds) are not part of the active stack, 128 GB is more than ample. Running databases (Vaultwarden SQLite, Prometheus TSDB, and Football Manager SQLite) on NVMe/SATA flash storage delivers vastly superior IOPS and near-zero latency compared to mechanical 5400 RPM hard drives.

> [!NOTE]
> All Docker volumes are mapped to `${DATA_DIR:-/opt/homelab/data}`. When secondary storage (such as a 1 TB HDD) is added in the future, mounting it and migrating the data directory requires modifying only a single line in `.env`.

---

## 3. Network Topology & Public IP Ingress

```
                 [ Public Internet / Telegram API ]       [ Admin Devices (Phone / Laptop) ]
                                 |                                         |
                         (HTTPS / Port 443)                     (Tailscale WireGuard Mesh)
                                 v                                         v
                      [ Public (White) WAN IP ]               [ Tailscale 100.x.x.x Interface ]
                                 |                                         |
                  +--------------+--------------+                          |
                  |   Router Port Forwarding    |                          |
                  |     (Ports 80, 443 -> Host) |                          |
                  +--------------+--------------+                          |
                                 |                                         |
                                 v                                         |
                 [ Nginx Reverse Proxy (Host: 443) ]                        |
                  (TLS Termination via Let's Encrypt)                       |
                                 |                                         |
                  +--------------+--------------+                          |
                  |                             |                          |
            (Public Path)                 (WAN Blocked)                    |
                  |                             |                          |
                  v                             v                          v
       [ /webhook/<your-app> ]          [ 403 Forbidden ] ---> [ Secure Tailscale Access ]
                  |                                           - Homepage (Dashboard)
                  v                                           - Vaultwarden (Passwords)
       [ Your Container / Bot ]                               - Pi-hole (DNS / Blocklist)
                                                              - Grafana / Kuma / Portainer
                                                              - Host SSH (Port 22)
```

### Verifying Public (White) IP vs CGNAT
To confirm your connection has a real public (white) IP rather than being trapped behind ISP Carrier-Grade NAT (CGNAT):
1. Check the external IP reported by the internet:
   ```bash
   curl -4 ifconfig.me
   ```
2. Log into your router's admin panel (Status / WAN section) and look at the **WAN IP Address**.
3. **If the WAN IP matches `curl ifconfig.me`**: You have a real public IP! You can port-forward ports `80` and `443` on your router to the laptop's LAN IP (`192.168.x.x`).
4. **If the WAN IP falls into CGNAT range (`100.64.0.0` - `100.127.255.255`) or RFC1918 private ranges (`10.x.x.x`, `192.168.x.x`, `172.16-31.x.x`)**: You are behind CGNAT. In that case, use **Cloudflare Tunnel (`cloudflared`)** or **Tailscale Funnel** to bypass the NAT without port forwarding.

### Ingress & Security Model
* **DuckDNS Dynamic Sync:** Queries the DuckDNS API every 5 minutes to keep public DNS records aligned with the dynamic WAN IP.
* **Nginx Reverse Proxy:** Terminating TLS with automated Let's Encrypt certificates.
* **Public Boundary:** Strictly scoped to explicit webhook paths. Rate limiting is enforced (`15r/s` burst `20`) to shield downstream apps from malicious traffic.
* **Private Boundary (Tailscale):** Management dashboards (Homepage, Portainer, Pi-hole, Uptime Kuma, Grafana) and Vaultwarden are protected by Nginx access control rules:
  ```nginx
  allow 100.64.0.0/10;   # Tailscale mesh
  allow 192.168.0.0/16;   # Local LAN
  deny all;               # Untrusted WAN
  ```

---

## 4. Service Catalog

| Service | Image | RAM Limit | Access Scope | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Nginx** | `nginx:alpine` | ~64 MB | Public (:80, :443) | Edge reverse proxy, TLS termination, ingress firewall |
| **Homepage** | `ghcr.io/gethomepage/homepage` | ~150 MB | Tailscale / LAN | Unified dashboard with system widgets & container telemetry |
| **Tailscale** | Host systemd / package | ~40 MB | Mesh VPN interface | Secure zero-trust remote administration (SSH & web services) |
| **Pi-hole** | `pihole/pihole` | ~250 MB | LAN / Tailscale (:53) | Network-wide ad blocking & split-horizon DNS (`*.lab`) |
| **Vaultwarden** | `vaultwarden/server:alpine` | ~100 MB | Tailscale / LAN | Lightweight self-hosted Bitwarden password manager |
| **Uptime Kuma** | `louislam/uptime-kuma` | ~200 MB | Tailscale / LAN | Endpoint health checks & Telegram alert dispatch |
| **Grafana** | `grafana/grafana-oss` | ~250 MB | Tailscale / LAN | Telemetry visual dashboards |
| **Prometheus** | `prom/prometheus` | ~350 MB | Internal Docker net | Metric collection & time-series database (15-day retention) |
| **Node Exporter** | `prom/node-exporter` | ~50 MB | Internal Docker net | Host hardware, CPU, RAM, and disk metrics exporter |
| **Portainer CE** | `portainer/portainer-ce` | ~100 MB | Tailscale / LAN | Docker container management UI |
| **DuckDNS Sync** | `linuxserver/duckdns` | ~30 MB | Outbound only | Dynamic DNS synchronization daemon |

*Total core container memory limits capped at ~1.5 GB, leaving >6 GB of free RAM for user workloads, Linux page caching, kernel buffers, and host operations.*

---

## 5. Dashboard: Homepage

[Homepage](https://gethomepage.dev) serves as the centralized launchpad and status monitor:
* **Docker Integration:** Direct read-only connection to `/var/run/docker.sock` displaying real-time container states, memory, and CPU usage.
* **System Widgets:** Live host metrics including CPU utilization, core temperatures, memory consumption, and SSD disk capacity.
* **Categorized Services:**
  * **Core Services:** Vaultwarden, Pi-hole, Portainer.
  * **Observability:** Uptime Kuma, Grafana, Prometheus.
  * **Applications:** Football Manager Bot, Tailscale Admin.
* **Configuration Directory:** Located in [`config/homepage/`](file:///config/homepage/).

---

## 6. Core Self-Hosted Services

### Vaultwarden
* Written in Rust; memory footprint under 50 MB compared to multi-gigabyte official Bitwarden stack.
* Isolated from public WAN. Accessible exclusively through Tailscale with HTTPS to satisfy WebCrypto API constraints.
* Persistent database stored at `/opt/homelab/data/vaultwarden`.

### Pi-hole
* Primary upstream DNS server for trusted home devices and Tailscale peers (via MagicDNS).
* Eliminates ads, tracking telemetry, and malware domains at the DNS query level.
* Resolves custom internal domain routes (e.g. `vault.lab`, `kuma.lab`, `grafana.lab`).

---

## 7. Deploying Custom Applications & Bots

The homelab is designed as a clean, decoupled platform. Any personal bots, tools, or web services (e.g., Telegram bots, scripts, APIs) run independently from their own repositories without cluttering the core homelab stack.

### How to Attach a Custom Service
To connect an external service or bot to the homelab network, attach it to the `homelab-net` Docker network in its own `docker-compose.yml`:

```yaml
# In your bot's personal docker-compose.yml:
services:
  my-bot:
    build: .
    container_name: my-bot
    restart: unless-stopped
    networks:
      - homelab-net
    environment:
      - BOT_TOKEN=your_token

networks:
  homelab-net:
    external: true
```

* **Access via Nginx:** If your application needs external webhooks or public ingress, add a location block in `config/nginx/conf.d/` pointing to `http://my-bot:<port>`.
* **Add to Homepage:** Add a card into [`config/homepage/services.yaml`](file:///config/homepage/services.yaml) to show real-time CPU/RAM stats on your dashboard.

---

## 8. Observability & Alert Pipeline

* **System Telemetry:** Prometheus scrapes host resource data from `node-exporter` every 15 seconds; Grafana visualizes load trends, temperatures, and storage health.
* **Service Availability:** Uptime Kuma runs continuous HTTP status checks and container heartbeat evaluations.
* **Incident Dispatch:** Critical service failures trigger immediate Telegram alerts via Bot API.
* **Outage Detection (Dead Man's Snitch):** Cron ping sent to an external Dead Man's Snitch endpoint every 5 minutes. If power or network fails, an external alert fires.

---

## 9. Automated Deployment via Ansible

The entire setup from bare-metal Debian 12 to a fully running homelab is automated via Ansible:

### Requirements on Target Machine
```bash
sudo apt update && sudo apt install -y git ansible
```

### Steps:
1. Clone the repository:
   ```bash
   git clone https://github.com/yeronymus/homelab.git
   cd homelab/ansible
   ```
2. Configure credentials and domains in `vars.yml`:
   ```bash
   nano vars.yml
   ```
3. Run the playbook:
   ```bash
   sudo ansible-playbook -i inventory.ini playbook.yml
   ```
4. Authenticate Tailscale:
   ```bash
   sudo tailscale up
   ```

### What Ansible Provisions:
1. System hardening, base utilities, and logind lid-switch ignore configuration.
2. TLP battery preservation policy.
3. Disabling `systemd-resolved` port 53 stub listener (freeing port 53 for Pi-hole).
4. SSD persistent data directory creation (`/opt/homelab/data/...`).
5. Official Docker Engine & Docker Compose plugin installation.
6. Tailscale installation and service activation.
7. UFW firewall rules (allow 22, 80, 443, and all traffic on `tailscale0`).
8. Environment file generation, SSL bootstrap, and `docker compose up -d`.
9. Backup and Dead Man's Snitch cron jobs.

---

## 10. Manual Deployment via Docker Compose

If deploying without Ansible:

```bash
# 1. Clone repository
git clone https://github.com/yeronymus/homelab.git /opt/homelab
cd /opt/homelab

# 2. Configure environment
cp .env.example .env
nano .env

# 3. Create persistent directories on SSD
mkdir -p /opt/homelab/data/{vaultwarden,pihole/etc-pihole,pihole/etc-dnsmasq.d,uptime-kuma,prometheus,grafana,portainer,football-manager}
mkdir -p /opt/homelab/backups
chmod 777 /opt/homelab/data/{prometheus,grafana}

# 4. Generate initial self-signed SSL certificate (for Nginx startup)
bash scripts/generate-self-signed-ssl.sh

# 5. Start Docker stack
docker compose up -d
```

---

## 11. Maintenance & Automation Scripts

* **Backup Volumes Script:** [`scripts/backup-volumes.sh`](file:///scripts/backup-volumes.sh) — Daily compressed archive of SQLite databases and data directories with 7-day retention.
* **DuckDNS Update Script:** [`scripts/duckdns-update.sh`](file:///scripts/duckdns-update.sh) — Dynamic IP synchronization.
* **Self-Signed SSL Generator:** [`scripts/generate-self-signed-ssl.sh`](file:///scripts/generate-self-signed-ssl.sh) — Bootstraps Nginx before real Let's Encrypt certificates are acquired.
