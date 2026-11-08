# Docker Ansible Deployment

This directory contains Ansible scripts to install Docker on target hosts.

## Overview

Installs Docker Engine (Community) from the official Docker APT repository, along with the Docker CLI, containerd, Buildx and Compose plugins. The playbook configures the daemon (`/etc/docker/daemon.json`) and adds the specified users to the `docker` group so they can run Docker without sudo.

## Features

- Installs Docker Engine from the **official Docker repository** (not the older Ubuntu `docker.io` package)
- Installs Docker CLI, containerd, Buildx and Compose plugins
- Configures the Docker daemon via a templated `daemon.json` (log rotation, extensible with extra options)
- Adds configured users to the `docker` group
- Enables and starts the `docker` service
- **Idempotent**: GPG key and repository are only added when missing

## Directory Structure

```
docker/
├── playbook.yml                  # Main playbook
├── inventory/
│   └── hosts.yml                 # Inventory file
├── roles/
│   └── docker/
│       ├── tasks/
│       │   └── main.yml          # Main installation tasks
│       ├── handlers/
│       │   └── main.yml          # Service handlers
│       ├── templates/
│       │   └── daemon.json.j2    # Docker daemon configuration template
│       ├── vars/
│       │   └── main.yml          # Environment-specific variables
│       └── defaults/
│           └── main.yml          # Default variables
├── vars-examples/
│   ├── development.yml           # Development environment example
│   └── production.yml            # Production environment example
├── ansible.cfg                   # Ansible configuration
├── install.sh                    # Installation script
├── validate.sh                   # Validation script
├── uninstall.sh                  # Uninstallation script
├── uninstall.yml                 # Uninstallation playbook
└── README.md                     # This file
```

## Prerequisites

- Ansible 2.9+ installed on the control machine
- Target hosts running Ubuntu/Debian (tested on Ubuntu 20.04+)
- SSH access to target hosts with sudo privileges
- Python 3 installed on target hosts
- Internet access from the target hosts (to reach `download.docker.com`)

## Quick Start

1. **Configure Inventory**: Edit `inventory/hosts.yml` with your server details:
   ```yaml
   all:
     children:
       docker_servers:
         hosts:
           docker-server:
             ansible_host: 192.168.56.10
   ```

2. **Test Connectivity**:
   ```bash
   ansible -i inventory/hosts.yml docker_servers -m ping
   ```

3. **Install Docker**:
   ```bash
   ./install.sh
   # or directly:
   ansible-playbook -i inventory/hosts.yml playbook.yml
   ```

4. **Verify Installation**:
   ```bash
   ssh user@192.168.56.10 'docker --version && docker run hello-world'
   ```

## Configuration

### Common Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `docker_repo_url` | "https://download.docker.com/linux/ubuntu" | Docker APT repository URL |
| `docker_gpg_key_url` | "https://download.docker.com/linux/ubuntu/gpg" | Docker GPG key URL |
| `docker_apt_arch` | auto-detected | Package architecture (amd64/arm64) |
| `docker_users` | ["user"] | Users added to the docker group |
| `docker_log_driver` | "json-file" | Default log driver |
| `docker_log_max_size` | "10m" | Max size of a container log file |
| `docker_log_max_file` | "3" | Number of rotated log files |
| `docker_extra_config` | "" | Extra raw JSON merged into daemon.json |

### Customization

Override default variables in `roles/docker/vars/main.yml` or pass them during playbook execution:

```bash
ansible-playbook -i inventory/hosts.yml playbook.yml \
  -e "docker_log_max_size=50m" \
  -e 'docker_users=["user","deploy"]'
```

To add extra daemon options (registry mirrors, insecure registries, ...), use `docker_extra_config` — the value is inserted raw into the JSON, so include the leading comma:

```yaml
docker_extra_config: ', "registry-mirrors": ["https://mirror.example.com"], "insecure-registries": ["192.168.56.10:5000"]'
```

## Network Ports

No ports are opened by Docker itself. Published container ports (`-p` / `ports:`) should be opened in the firewall as needed.

## Service Management

```bash
# Check status
sudo systemctl status docker

# Restart
sudo systemctl restart docker

# Logs
journalctl -u docker -f
```

### Verify Docker works

```bash
# Run without sudo (requires membership in the docker group; re-login after first playbook run)
docker run hello-world
```

## Troubleshooting

1. **`permission denied` on docker CLI**: the user must be in the `docker` group — log out and back in after the playbook ran (`groups` to verify).
2. **Repository GPG errors**: check `/etc/apt/keyrings/docker.asc` exists and `apt update` succeeds on the target.
3. **Old docker.io installed**: the playbook installs `docker-ce` from Docker's repo; remove `docker.io` manually if it conflicts.

### Verification Commands

```bash
docker --version
docker compose version
sudo systemctl status docker
docker info | grep -A2 "Log Driver"
```

## Support

For issues related to:
- **Ansible deployment**: Check this README and Ansible documentation
- **Docker configuration**: Refer to [Docker Documentation](https://docs.docker.com/engine/install/ubuntu/)

## License

This Ansible configuration is provided under the Apache License 2.0, same as the main repository.
