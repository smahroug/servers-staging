# Airflow Ansible Deployment

This directory contains Ansible scripts to deploy **Apache Airflow 2.10.5** (scheduler + webserver UI) on a target host, backed by a local **PostgreSQL** metadata database and the **LocalExecutor**.

## Overview

Apache Airflow is a platform to programmatically author, schedule and monitor workflows. This role installs a complete single-node Airflow stack:

- Airflow **scheduler** (systemd service)
- Airflow **webserver** — the **Web UI** (systemd service, port 8080)
- Local **PostgreSQL** as the metadata database
- LocalExecutor to run tasks on the same host
- Admin user created for the UI login

## Features

- Installs Airflow via `pip` with the official **constraints** URL (deterministic builds)
- Python **virtual environment** dedicated to Airflow (`/opt/airflow-venv`)
- Installs and configures **PostgreSQL** (db + user + privileges)
- Creates a dedicated `airflow` system user
- Generates `airflow.cfg` from a template
- Runs `airflow db migrate`, creates the **admin UI user**
- Two hardened **systemd** services: `airflow-scheduler`, `airflow-webserver`
- Log rotation for Airflow logs
- Idempotent: re-running the playbook only applies changes

## Directory Structure

```
airflow/
├── playbook.yml                    # Main playbook
├── uninstall.yml                   # Uninstallation playbook
├── install.sh                      # Installation script (validate + deploy)
├── uninstall.sh                    # Uninstallation script
├── validate.sh                     # Pre-deployment validation script
├── ansible.cfg                     # Ansible configuration
├── inventory/
│   ├── hosts.yml                   # Inventory file
│   └── hosts.yml.template          # Inventory template
├── roles/
│   └── airflow/
│       ├── tasks/
│       │   └── main.yml            # Main installation tasks
│       ├── handlers/
│       │   └── main.yml            # Service handlers
│       ├── templates/
│       │   ├── airflow.cfg.j2                  # Airflow configuration template
│       │   ├── airflow-scheduler.service.j2    # Scheduler systemd unit template
│       │   └── airflow-webserver.service.j2    # Webserver systemd unit template
│       ├── vars/
│       │   └── main.yml             # Environment-specific variables
│       └── defaults/
│           └── main.yml             # Default variables
├── vars-examples/
│   ├── development.yml              # Development profile
│   ├── production.yml               # Production profile
│   └── security.yml                 # Security hardening profile
└── README.md                        # This file
```

## Prerequisites

- Ansible 2.9+ installed on the control machine (requires `community.general` for the PostgreSQL modules)
- Target host running Ubuntu/Debian (tested on Ubuntu 20.04, Python 3.8)
- SSH access to the target host with sudo privileges
- Internet access on the target host for pip/PyPI

> The role targets **Python 3.8** (Ubuntu 20.04 default) and therefore installs **Airflow 2.10.5**, the last version supporting it. For Python 3.9+, override `airflow_version` and `airflow_constraints_url`.

## Quick Start

### 1. Configure Inventory

Edit `inventory/hosts.yml` with your server details:

```yaml
all:
  children:
    airflow_servers:
      hosts:
        airflow-server:
          ansible_host: 192.168.56.6
      vars:
        ansible_user: user
        ansible_password: "user"
        ansible_become: true
        ansible_become_method: sudo
```

For production, use the secure template:

```bash
cp inventory/hosts.yml.template inventory/hosts.yml
# Edit inventory/hosts.yml with your server details and SSH key path
```

### 2. Choose Configuration Profile (Optional)

```bash
# For development
cp vars-examples/development.yml roles/airflow/vars/main.yml

# For production
cp vars-examples/production.yml roles/airflow/vars/main.yml

# For security hardening
cp vars-examples/security.yml roles/airflow/vars/main.yml
```

### 3. Test Connectivity

```bash
ansible -i inventory/hosts.yml airflow_servers -m ping
```

### 4. Deploy Airflow

```bash
# Run installation script with validation
./install.sh

# Or run directly with additional options
ansible-playbook -i inventory/hosts.yml playbook.yml --ask-become-pass --diff
```

The first run downloads all Python dependencies — expect **5 to 15 minutes**.

### 5. Verify Installation

```bash
# Check both services
ansible -i inventory/hosts.yml airflow_servers -m shell \
  -a "systemctl status airflow-scheduler airflow-webserver"

# Check the UI from your machine
open http://192.168.56.6:8080
```

Log in with the credentials from `airflow_admin_user` / `airflow_admin_password` (default `admin` / `admin`).

## Configuration

### Default Settings

The role comes with sensible defaults in `roles/airflow/defaults/main.yml`:

- **Airflow version**: 2.10.5 (constraints-3.8)
- **Executor**: LocalExecutor
- **Database**: PostgreSQL 12 (Ubuntu 20.04 default), local, `airflow`/`airflow`
- **Web UI**: 0.0.0.0:8080
- **Admin**: `admin` / `admin`
- **DAGs**: `/opt/airflow/dags`, examples disabled

### Common Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `airflow_version` | "2.10.5" | Airflow version to install |
| `airflow_constraints_url` | constraints-3.8 | Constraints URL (must match version + Python) |
| `airflow_home` | /opt/airflow | AIRFLOW_HOME (config, DAGs, logs) |
| `airflow_venv` | /opt/airflow-venv | Dedicated Python venv |
| `airflow_webserver_port` | 8080 | Web UI port |
| `airflow_web_server_host` | 0.0.0.0 | Web UI bind address |
| `airflow_webserver_secret` | "" | Session cookie secret (set in production!) |
| `airflow_executor` | LocalExecutor | Task executor |
| `airflow_db_name` / `airflow_db_user` / `airflow_db_password` | airflow/airflow/airflow | Metadata DB settings |
| `airflow_admin_user` / `airflow_admin_password` | admin/admin | Web UI admin login |
| `airflow_fernet_key` | "" | Fernet key for sensitive data (set in production) |
| `airflow_load_examples` | false | Install the example DAGs |
| `airflow_start_services` | true | Start services after install |
| `airflow_enable_services` | true | Enable services at boot |

## Network Ports

| Service | Port | Description |
|---------|------|-------------|
| Airflow Webserver (UI) | 8080 | Web interface |
| PostgreSQL | 5432 | Metadata DB (localhost only by default) |

## Service Management

```bash
# Start / stop / status
sudo systemctl start airflow-scheduler airflow-webserver
sudo systemctl stop airflow-scheduler airflow-webserver
sudo systemctl status airflow-scheduler airflow-webserver

# Logs
journalctl -u airflow-scheduler -f
journalctl -u airflow-webserver -f
tail -f /opt/airflow/logs/scheduler/*.log
```

## Basic Usage

```bash
# Switch to the airflow user with the right environment
sudo su - airflow -s /bin/bash
export AIRFLOW_HOME=/opt/airflow
export PATH=/opt/airflow-venv/bin:$PATH

# Trigger the CLI (same credentials environment as the services)
airflow dags list
airflow dags trigger <dag_id>
airflow tasks list <dag_id>
```

Deploy your DAGs into `/opt/airflow/dags/` — the scheduler picks them up automatically.

## Uninstallation

```bash
./uninstall.sh
# Or directly:
ansible-playbook -i inventory/hosts.yml uninstall.yml --ask-become-pass
```

This removes both services, `/opt/airflow` (config, DAGs, logs), `/opt/airflow-venv`, the PostgreSQL database and user, the log rotation config and the `airflow` user/group.

## Security Considerations

- Default credentials (`admin/admin`, `airflow/airflow`) are for **staging only** — override them via `vars-examples/security.yml`
- Set `airflow_webserver_secret` and `airflow_fernet_key` in production
- The systemd services run with hardening (`NoNewPrivileges`, `ProtectSystem`, ...) and a dedicated `airflow` user
- Use SSH key-based authentication and ansible-vault instead of plain passwords in the inventory

## Troubleshooting

### Common Issues

1. **Web UI not reachable**: check `systemctl status airflow-webserver` and `journalctl -u airflow-webserver -f`
2. **Scheduler not picking up DAGs**: check `journalctl -u airflow-scheduler -f` and permissions on `/opt/airflow/dags`
3. **DB connection errors**: verify PostgreSQL is running (`pg_lsclusters`) and the credentials in `airflow_db_conn`
4. **pip install fails / takes forever**: the role retries 3 times; check internet access on the VM

### Verification Commands

```bash
# Check if Airflow components are running
ps aux | grep -E "airflow (scheduler|webserver)"

# Check webserver port
ss -tlnp | grep 8080

# Health endpoint
curl http://localhost:8080/health
```

## Support

For issues related to:
- **Ansible deployment**: check this README and Ansible documentation
- **Airflow configuration**: refer to the [Apache Airflow Documentation](https://airflow.apache.org/docs/)

## License

This Ansible configuration is provided under the Apache License 2.0, same as the main repository.

