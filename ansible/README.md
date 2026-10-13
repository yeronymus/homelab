# Homelab Ansible Automation

Production-ready Infrastructure-as-Code (IaC) to bootstrap a fresh Debian 12 (or Ubuntu) node into a fully configured, containerized homelab server.

## Features

* **Universal & Idempotent:** Safe to run multiple times without breaking existing configuration.
* **Auto-detects Non-root User:** Automatically grants Docker permissions and folder ownership to whichever user runs `sudo ansible-playbook`.
* **Zero Sleep on Lid Close:** Laptop lid switch is set to ignore (`systemd-logind`), allowing 24/7 headless operation with the laptop closed.
* **Battery Longevity:** Enables `tlp` to protect the laptop battery during continuous AC power.
* **Docker & Compose Engine:** Installs official Docker CE and compose plugin from the official Docker APT repositories.
* **Tailscale Mesh VPN:** Installs and enables `tailscaled` for private WireGuard mesh networking.
* **Hardened Firewall (UFW):** Blocks all unsolicited public inbound traffic while allowing SSH (22), HTTP/HTTPS (80/443), and unrestricted access across the secure `tailscale0` VPN interface.
* **Automatic Service Orchestration:** Clones the stack, prepares fast SSD directories, bootstraps SSL, deploys `.env`, and launches all containers.

---

## Quick Start (Fresh Debian Installation)

### 1. Initial Host Setup (if fresh minimal Debian)
If you installed Debian without GUI or offline, ensure your non-root user has `sudo` rights:

```bash
# Switch to root
su -

# Ensure official APT repositories are enabled
cat << 'EOF' > /etc/apt/sources.list
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
EOF

# Install essentials and add user to sudoers
apt update && apt install -y sudo curl git
usermod -aG sudo $USER
exit
```

### 2. Run Ansible Provisioning
Log in as your normal user (e.g. over SSH):

```bash
# 1. Install Ansible
sudo apt update && sudo apt install -y ansible git

# 2. Clone homelab repository
git clone https://github.com/yeronymus/homelab.git
cd homelab/ansible

# 3. Optional: Customize passwords / domain in vars.yml
nano vars.yml

# 4. Run the playbook!
sudo ansible-playbook -i inventory.ini playbook.yml
```

### 3. Connect to Tailscale
Once the playbook completes:
```bash
sudo tailscale up
```
Authenticate via the provided URL or auth key.

---

## Post-Install Service Access

Once connected to your Tailscale network, access all homelab services via your server's Tailscale IP (e.g., `https://100.x.y.z/`):

| Service | Path | Purpose | Initial Setup |
| :--- | :--- | :--- | :--- |
| **Homepage** | `/` | Main Unified Dashboard | Preconfigured with live container & CPU widgets |
| **Vaultwarden** | `/vault/` | Bitwarden Password Manager | Register your personal account |
| **Uptime Kuma** | `/kuma/` | Service Heartbeats & Status | Set up admin user on first visit |
| **Portainer CE** | `/portainer/` | Docker Container Web GUI | Set admin password within 5 minutes |
| **Grafana** | `/grafana/` | Host Metrics & Dashboards | Default user: `admin`, password from `.env` |
| **Pi-hole** | `/admin/` | Ad-blocking & Local DNS | Password set in `.env` (`PIHOLE_PASSWORD`) |

---

## Troubleshooting & Tips

* **Tailscale DNS Conflict on Client:** If your client computer loses internet after joining Tailscale, go to [login.tailscale.com/admin/dns](https://login.tailscale.com/admin/dns) and disable **Override local DNS** unless a working nameserver is explicitly configured.
* **Adding Custom Services:** Put your personal bots and standalone apps in separate folders or repositories; connect them to `homelab-net` Docker network to communicate with Nginx or Prometheus.
