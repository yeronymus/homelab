# Homelab Ansible Automation

This directory contains automated infrastructure-as-code playbooks to provision a clean Debian 12 (or Ubuntu) node from scratch.

## What This Playbook Does Automatically:

1. **System & Power Hardening**:
   - Updates APT and installs base utilities (`curl`, `git`, `htop`, `ufw`, `fail2ban`, `tlp`).
   - Configures `systemd-logind` to prevent sleep/hibernation when closing the laptop lid (`HandleLidSwitch=ignore`).
   - Enables `tlp` battery life preservation for 24/7 plugged-in operation.
2. **Network & DNS Preparation**:
   - Resolves port 53 conflict by disabling `systemd-resolved` stub listener, allowing Pi-hole to bind directly.
3. **Storage Provisioning (Virtual 1TB HDD)**:
   - If a physical 1 TB drive is not yet connected, it creates an ext4 sparse disk image (`virtual-hdd.img`) that consumes 0 physical bytes initially and mounts it at `/mnt/hdd` via `/etc/fstab`.
   - Initializes required directory hierarchy (`/mnt/hdd/data/...`).
4. **Containerization**:
   - Installs official Docker Engine and Docker Compose plugin.
   - Adds your user to the `docker` group.
5. **Tailscale Mesh VPN**:
   - Installs and enables `tailscaled`.
6. **Firewall (UFW)**:
   - Denies all unsolicited incoming traffic.
   - Allows SSH (22), HTTP (80), and HTTPS (443).
   - Allows all traffic over the secure `tailscale0` VPN interface.
7. **Homelab Deployment**:
   - Clones repository to `/opt/homelab`.
   - Provisions `.env` and generates initial self-signed SSL certificates for Nginx.
   - Sets up daily backup and Dead Man's Snitch cron jobs.
   - Starts all containers via `docker compose up -d`.

---

## Quick Start (Run Locally on the Target Machine)

```bash
# 1. Install git and ansible
sudo apt update && sudo apt install -y git ansible

# 2. Clone this repo
git clone https://github.com/yeronymus/homelab.git
cd homelab/ansible

# 3. Adjust variables in vars.yml (tokens, domain, passwords)
nano vars.yml

# 4. Run playbook locally
sudo ansible-playbook -i inventory.ini playbook.yml

# 5. Authenticate Tailscale
sudo tailscale up
```

## Running Remotely from another Machine

Edit `inventory.ini` to specify your laptop's IP address and SSH credentials:

```ini
[homelab]
laptop ansible_host=192.168.1.50 ansible_user=yeronym
```

Then run:

```bash
ansible-playbook -i inventory.ini playbook.yml -K
```
