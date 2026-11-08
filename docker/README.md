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
| `docker_api_hosts` | [] | Daemon `-H` listeners (e.g. `tcp://0.0.0.0:2375`); empty = unix socket only |
| `docker_api_firewall_sources` | [] | ufw source CIDRs allowed to reach the Docker API |
| `docker_firewall_allow_ports` | [] | Extra ufw allowances for published container ports (e.g. `5432/tcp`) |

### Remote Docker API access

By default the daemon only listens on the local unix socket. To use the API from
another machine (e.g. your host against a VirtualBox VM), enable a TCP listener:

```yaml
docker_api_hosts:
  - "unix:///var/run/docker.sock"
  - "tcp://0.0.0.0:2375"
docker_api_firewall_sources:
  - "192.168.56.0/24"   # restrict to trusted networks
```

The role installs a systemd drop-in (`/etc/systemd/system/docker.service.d/docker-api.conf`)
that overrides `ExecStart` with the configured `-H` flags, and opens port 2375 in
ufw **only** for the listed source CIDRs.

> **Warning:** port 2375 is unauthenticated and unencrypted — anyone who can reach it has
> root-equivalent control over the host. Only use it on trusted/isolated networks
> (lab VMs, host-only adapters). For anything shared, use 2376 with TLS
> (`dockerd --tlsverify` + CA/client certs) instead.

Verify from your machine:

```bash
nc -vz 192.168.56.10 2375
curl http://192.168.56.10:2375/version
```

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

## PostgreSQL

The playbook also deploys a PostgreSQL container (role `postgres`) that is published on all host interfaces, so it is reachable from your machine at `192.168.56.10:5432`.

| Variable | Default | Description |
|----------|---------|-------------|
| `postgres_image` | "postgres:17" | Container image |
| `postgres_container_name` | "postgres" | Container name |
| `postgres_port` | 5432 | Host port to publish |
| `postgres_bind_address` | "0.0.0.0" | Address to bind the published port |
| `postgres_db` | "appdb" | Database created on first start |
| `postgres_user` | "postgres" | Superuser name |
| `postgres_password` | "postgres" | Superuser password |
| `postgres_data_dir` | "/opt/postgres/data" | Host directory for data persistence |
| `postgres_restart_policy` | "unless-stopped" | Container restart policy |

Override credentials/ports the same way as Docker variables:

```bash
ansible-playbook -i inventory/hosts.yml playbook.yml \
  -e 'postgres_password=secret' -e postgres_port=5433
```

Connect from your machine (e.g. with `psql`):

```bash
psql -h 192.168.56.10 -p 5432 -U postgres -d appdb
```

Data survives container restarts and reboots via the bind mount at `/opt/postgres/data`.

## Network Ports

The PostgreSQL container publishes port **5432** on all host interfaces (`0.0.0.0:5432 -> 5432`). Other published container ports (`-p` / `ports:`) should be opened in the firewall as needed.

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
