# Personal Homelab & Self-Hosted Infrastructure

A compact, single-node production homelab built on repurposed laptop hardware. Designed to host self-hosted daily utilities, provide secure credential management, serve internal DNS with network-wide ad blocking, run a webhook-based Telegram bot runtime, maintain system observability, and handle secure external ingress alongside encrypted remote administration.

## Quick Summary

* **Hardware:** HP Pavilion 14 (Intel Core i5-8265U 4C/8T, 8 GB RAM, 128 GB SSD + 1 TB HDD).
* **Base OS:** Debian 12 Minimal.
* **Ingress & Networking:** Dynamic Public IP synchronized via **DuckDNS**, automated **Let's Encrypt SSL**, and **Nginx Reverse Proxy**. Public ingress is strictly scoped to the bot webhook endpoint.
* **Network & DNS:** **Pi-hole** deployed as an internal DNS sinkhole for network-wide ad blocking and custom local domain resolution (`*.lab`).
* **Self-Hosted Productivity:** **Vaultwarden** (lightweight Bitwarden implementation) for encrypted personal secret and password management.
* **Remote Management:** **Tailscale (WireGuard Mesh)** deployed for encrypted administrative access (SSH, Grafana, Portainer, Vaultwarden, Pi-hole) from authorized personal devices without exposing management ports to the internet.
* **Core Workload:** Self-hosted production environment running the [`football-manager`](https://github.com/yeronymus/football-manager) Telegram bot daemon.
* **Observability:** Prometheus + Grafana telemetry stack, local Uptime Kuma for service heartbeats, and an external Dead Man's Snitch ping for power and upstream connection outages.
* **Orchestration:** Docker Compose with scheduled volume backup automation.

## Table of Contents

1. [Hardware Specifications](#1-hardware-specifications)
2. [Operating System & Architectural Decisions](#2-operating-system--architectural-decisions)
3. [Network Topology & Access Control](#3-network-topology--access-control)
4. [Service Catalog](#4-service-catalog)
5. [Core Self-Hosted Services](#5-core-self-hosted-services)
6. [Workload: Football Manager Bot](#6-workload-football-manager-bot)
7. [Observability & Alert Pipeline](#7-observability--alert-pipeline)
8. [Maintenance & Automation Scripts](#8-maintenance--automation-scripts)

## 1. Hardware Specifications

* **Host Machine:** HP Pavilion 14-ce1005ur
* **CPU:** Intel Core i5-8265U (4 cores / 8 threads, up to 3.90 GHz)
* **RAM:** 8 GB DDR4-2400 MHz
* **Storage:** 128 GB M.2 SATA SSD (OS & core configurations) + 1 TB 5400 rpm HDD (persistent Docker volumes, database storage, backup archives)
* **Networking:** Realtek Gigabit Ethernet (RTL8111/8168/8411)
* **Power & Thermal Policy:**
  * Headless lid behavior managed via `systemd-logind` (`HandleLidSwitch=ignore`).
  * TLP deployed to control charge thresholds and reduce battery thermal wear under constant 24/7 AC power.

## 2. Operating System & Architectural Decisions

### Proxmox VE vs. Minimal Linux

During the early exploratory stage, **Proxmox VE (PVE 8.x)** was evaluated on the node for hypervisor experimentation. However, given the physical 8 GB memory limit, the virtualization overhead and fixed KVM allocations were unnecessary for running lightweight services.

The system was deployed on bare-metal **Debian 12 (Bookworm) Minimal**:
* Headless deployment with no desktop environment or display manager.
* Low base footprint, leaving the majority of memory resources for container workloads.
* Unified service orchestration and process isolation managed via **Docker** and **Docker Compose**.

## 3. Network Topology & Access Control

```
                 [ Public Internet / Telegram API ]       [ Admin Devices (Phone / Laptop) ]
                                 |                                         |
                         (HTTPS / Port 443)                     (Tailscale WireGuard Mesh)
                                 v                                         v
               [ Dynamic Public IP (Dormitory WAN) ]          [ Tailscale 100.x.x.x Interface ]
                                 |                                         |
                  +--------------+--------------+                          |
                  |   DuckDNS Dynamic DNS Sync   |                          |
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
    [ /webhook/football-manager ]       [ 403 Forbidden ] ---> [ Secure Tailscale Access ]
                  |                                           - Vaultwarden (Passwords)
                  v                                           - Pi-hole (DNS / Blocklist)
    [ football-manager Container ]                            - Grafana / Kuma / Portainer
                                                              - Host SSH
```

* **Dynamic DNS (DuckDNS):** A scheduled cron runner queries the DuckDNS API every 5 minutes to keep public DNS records aligned with the dynamic WAN IP.
* **Edge Routing & Ingress:** Nginx acts as the perimeter reverse proxy, terminating HTTPS via automated Let's Encrypt certificates provisioned by Certbot.
* **Dual-Layer Access Model:**
  * **Public Ingress:** Restricted solely to the `/webhook/...` path required by Telegram Bot API updates.
  * **Private Administration (Tailscale):** Management dashboards (Grafana, Portainer, Uptime Kuma), Pi-hole web UI, and Vaultwarden are bound to the Tailscale mesh IP (`100.x.x.x`) and local LAN, completely unreachable from the public WAN.

## 4. Service Catalog

| Service | Image | Memory Limit | Access Scope | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Nginx** | `nginx:alpine` | ~30 MB | Public (:80, :443) | Edge reverse proxy, TLS termination, ingress filtering |
| **Tailscale** | `tailscale/tailscale` | ~40 MB | Mesh VPN interface | Secure remote administration for SSH and internal services |
| **Pi-hole** | `pihole/pihole` | ~150 MB | LAN / Tailscale (:53) | Network-wide ad blocking & split-horizon DNS (`*.lab`) |
| **Vaultwarden** | `vaultwarden/server:alpine` | ~50 MB | Tailscale / LAN | Lightweight self-hosted Bitwarden password manager |
| **DuckDNS Updater** | Bash cron | ~5 MB | Outbound only | Dynamic DNS synchronization daemon |
| **Football Manager** | Custom build | ~120 MB | Internal container | Telegram bot production daemon ([Source Code](https://github.com/yeronymus/football-manager)) |
| **Uptime Kuma** | `louislam/uptime-kuma` | ~180 MB | Tailscale / LAN | Endpoint health checks & Telegram alert dispatch |
| **Grafana** | `grafana/grafana-oss` | ~220 MB | Tailscale / LAN | Telemetry visual dashboards |
| **Prometheus** | `prom/prometheus` | ~300 MB | Internal Docker net | Metric collection & time-series storage |
| **Node Exporter** | `prom/node-exporter` | ~20 MB | Internal Docker net | Host hardware and OS telemetry exporter |
| **Portainer CE** | `portainer/portainer-ce` | ~80 MB | Tailscale / LAN | Docker container management UI |

## 5. Core Self-Hosted Services

### Vaultwarden (Bitwarden Alternative)
* **Architecture:** Written in Rust, running via `vaultwarden/server:alpine`, consuming under 50 MB RAM compared to the multi-gigabyte footprint of official upstream Bitwarden.
* **Security & Access:** Completely isolated from public WAN. Accessible exclusively via Tailscale mesh VPN with internal TLS certificates to satisfy WebCrypto API requirements.
* **Storage & Backups:** Vaultwarden SQLite database and RSA keyrings are mounted on persistent storage and included in daily automated backup archives.

### Pi-hole (DNS Sinkhole & Local Domains)
* **Ad-blocking & Privacy:** Serves as the primary upstream DNS server for trusted devices, blocking tracking and telemetry at the DNS level.
* **Custom Local Records:** Resolves convenient internal domain routes (e.g., `vault.lab`, `kuma.lab`, `grafana.lab`) over the private network.

## 6. Workload: Football Manager Bot

The node serves as the primary production runtime for the [`football-manager`](https://github.com/yeronymus/football-manager) Telegram bot.

* **Webhook Architecture:** Operates using incoming Telegram Webhooks over HTTPS rather than long-polling, avoiding persistent idle connections.
* **Storage Decoupling:** Persistent database files, logs, and state are mounted from the secondary 1 TB hard drive (`/mnt/hdd/data/football-manager`).
* **Container Resilience:** Automated container recovery handled via Docker's `restart: unless-stopped` restart policy.

## 7. Observability & Alert Pipeline

* **System Telemetry:** Prometheus scrapes host resource data from `node-exporter` every 15 seconds; Grafana visualizes load trends, temperatures, and storage health.
* **Service Availability:** Uptime Kuma runs continuous HTTP status checks and container heartbeat evaluations.
* **Incident Dispatch:** Critical failures trigger immediate notification events sent directly to an administrative Telegram chat via Bot API.
* **Host Outage Detection (Dead Man's Snitch):** To monitor node availability during complete power or upstream connectivity failures, a cron job sends a heartbeat ping to an external endpoint every 5 minutes. If missed, an external alert is generated.

## 8. Maintenance & Automation Scripts

### 1. Lid Switch Ignore Configuration
```ini
# /etc/systemd/logind.conf
[Login]
HandleLidSwitch=ignore
HandleLidSwitchDocked=ignore
```

### 2. DuckDNS Dynamic DNS Sync
```bash
# /etc/cron.d/duckdns (runs every 5 minutes)
*/5 * * * * root curl -s "https://www.duckdns.org/update?domains=YOUR_DOMAIN&token=YOUR_TOKEN&ip=" >/dev/null 2>&1
```

### 3. External Heartbeat Ping (Dead Man's Snitch)
```bash
# /etc/cron.d/heartbeat (runs every 5 minutes)
*/5 * * * * root curl -fsS --retry 3 https://nosnch.in/YOUR_TOKEN >/dev/null 2>&1
```

### 4. Volume Backup Script
```bash
# /etc/cron.daily/homelab-backup
0 4 * * * root /opt/scripts/backup-volumes.sh
```
