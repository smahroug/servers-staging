# SonarQube Ansible Deployment

This directory contains Ansible scripts to deploy SonarQube on target hosts.

## Overview

SonarQube is an open-source platform for continuous inspection of code quality. It performs automatic reviews with static analysis of code to detect bugs, code smells, and security vulnerabilities. This Ansible playbook automates the installation and configuration of SonarQube on your servers.

## Features

- **Smart Java Detection**: Automatically detects existing Java installations and only installs Java 17 if needed
- Downloads and installs SonarQube Community Edition
- Configures SonarQube with systemd for automatic startup
- Supports both embedded H2 (testing) and PostgreSQL (production) databases
- Configurable memory settings for Web, Compute Engine, and Elasticsearch
- Security hardened systemd service configuration
- **Dynamic JAVA_HOME Configuration**: Automatically configures JAVA_HOME based on detected Java installation
- Sets proper system limits (nofile, nproc, vm.max_map_count) required by Elasticsearch

## Directory Structure

```
sonarqube/
├── playbook.yml                  # Main playbook
├── inventory/
│   └── hosts.yml                 # Inventory file
├── roles/
│   └── sonarqube/
│       ├── tasks/
│       │   └── main.yml          # Main installation tasks
│       ├── handlers/
│       │   └── main.yml          # Service handlers
│       ├── templates/
│       │   ├── sonar.properties.j2    # SonarQube configuration template
│       │   └── sonarqube.service.j2   # Systemd service template
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
└── README.md                     # This file
```

## Prerequisites

- Ansible 2.9+ installed on the control machine
- Target hosts running Ubuntu/Debian (tested on Ubuntu 20.04+)
- SSH access to target hosts with sudo privileges
- Python 3 installed on target hosts
- **For production**: PostgreSQL database (version 11+)
- Minimum 4 GB RAM recommended (Elasticsearch requires at least 2 GB)

## Quick Start

1. **Configure Inventory**: Edit `inventory/hosts.yml` with your server details:
   ```yaml
   all:
     children:
       sonarqube_servers:
         hosts:
           sonarqube-server:
             ansible_host: 172.16.100.140
   ```

2. **Test Connectivity**:
   ```bash
   ansible -i inventory/hosts.yml sonarqube_servers -m ping
   ```

3. **Deploy SonarQube**:
   ```bash
   ansible-playbook -i inventory/hosts.yml playbook.yml
   ```

4. **Verify Installation**:
   - Access SonarQube Web UI: `http://your-server-ip:9000`
   - Default credentials: `admin` / `admin`
   - Check service status: `systemctl status sonarqube`

## Configuration

### Default Settings

The role comes with sensible defaults in `roles/sonarqube/defaults/main.yml`:

- **SonarQube Version**: 10.6.0.92116 (Community Edition)
- **Java Version**: OpenJDK 17
- **Memory Settings**:
  - Web JVM: 512m min / 2048m max
  - Compute Engine JVM: 512m min / 2048m max
  - Elasticsearch JVM: 512m min / 512m max
- **Database**: PostgreSQL (configurable)
- **Web Port**: 9000

### Customization

Override default variables in `roles/sonarqube/vars/main.yml` or pass them during playbook execution:

```bash
ansible-playbook -i inventory/hosts.yml playbook.yml \
  -e "sonarqube_web_java_opts='-Xms1024m -Xmx4096m -XX:+HeapDumpOnOutOfMemoryError'" \
  -e "sonarqube_db_password=secure_password"
```

### Common Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `sonarqube_version` | "10.6.0.92116" | SonarQube version to install |
| `sonarqube_web_port` | 9000 | Web UI port |
| `sonarqube_web_java_opts` | "-Xms512m -Xmx2048m..." | Web server JVM options |
| `sonarqube_ce_java_opts` | "-Xms512m -Xmx2048m..." | Compute Engine JVM options |
| `sonarqube_es_java_opts` | "-Xms512m -Xmx512m..." | Elasticsearch JVM options |
| `sonarqube_db_type` | "postgresql" | Database type (h2 or postgresql) |
| `sonarqube_db_host` | "localhost" | Database host |
| `sonarqube_db_name` | "sonarqube" | Database name |

## Java Detection and Installation

The playbook includes intelligent Java detection that:

- **Detects existing Java installations** using `which java` command and common installation paths
- **Supports multiple Java distributions**: OpenJDK, Oracle JDK, Temurin, Amazon Corretto, etc.
- **Only installs Java if needed**: Skips Java installation if a compatible version is already present
- **Automatically configures JAVA_HOME**: Uses detected Java installation path in SonarQube configuration
- **Fallback installation**: Installs OpenJDK 17 if no Java is found

> **Note**: SonarQube 10.x requires Java 17. The playbook will install OpenJDK 17 if not already present.

## Network Ports

| Service | Port | Description |
|---------|------|-------------|
| Web UI | 9000 | SonarQube dashboard |
| Elasticsearch | 9001 | Internal search engine |

Ensure these ports are open in your firewall configuration.

## Service Management

### Start/Stop Services

```bash
# Start SonarQube
sudo systemctl start sonarqube

# Stop SonarQube
sudo systemctl stop sonarqube

# Check status
sudo systemctl status sonarqube

# View logs
journalctl -u sonarqube -f
```

### Manual Start/Stop (Alternative)

```bash
# Start SonarQube
sudo -u sonarqube /opt/sonarqube/bin/linux-x86-64/sonar.sh start

# Stop SonarQube
sudo -u sonarqube /opt/sonarqube/bin/linux-x86-64/sonar.sh stop

# Restart SonarQube
sudo -u sonarqube /opt/sonarqube/bin/linux-x86-64/sonar.sh restart

# Check status
sudo -u sonarqube /opt/sonarqube/bin/linux-x86-64/sonar.sh status
```

## Database Setup (PostgreSQL)

For production use, set up a PostgreSQL database before running the playbook:

```sql
CREATE USER sonarqube WITH PASSWORD 'your_secure_password';
CREATE DATABASE sonarqube OWNER sonarqube;
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonarqube;
```

Then update the database variables in your vars or inventory.

## Troubleshooting

### Common Issues

1. **Java not found**: The playbook automatically detects existing Java installations. SonarQube 10.x requires Java 17.
2. **Elasticsearch fails to start**: Ensure `vm.max_map_count` is set to at least 262144. The playbook configures this automatically.
3. **Permission denied**: Check that the `sonarqube` user has proper permissions on data/log directories.
4. **Memory issues**: SonarQube + Elasticsearch require significant memory. Ensure at least 4 GB RAM available.
5. **Port conflicts**: Ensure ports 9000 and 9001 are not in use by other services.

### Log Locations

- SonarQube logs: `/opt/sonarqube/logs/`
- System logs: `/var/log/sonarqube/`
- Systemd service logs: `journalctl -u sonarqube`
- Elasticsearch logs: `/opt/sonarqube/logs/es.log`

### Verification Commands

```bash
# Check if SonarQube is running
ps aux | grep sonarqube

# Check network connectivity
netstat -tlnp | grep 9000

# Check service status
systemctl status sonarqube

# Test web UI
curl -I http://localhost:9000
```

## Security Considerations

- The systemd service runs with security hardening (`NoNewPrivileges`, `ProtectSystem`, `PrivateTmp`)
- SonarQube runs as a dedicated `sonarqube` user with minimal privileges
- Change the default admin password after first login
- Use a reverse proxy (Nginx/Apache) with HTTPS for production
- Use PostgreSQL instead of embedded H2 for production
- Configure firewall to restrict access to the web port

## Monitoring

Monitor your SonarQube instance using:

1. **SonarQube Web UI**: Built-in dashboard at `http://server:9000`
2. **System monitoring**: Monitor CPU, memory, and disk usage
3. **Logging**: Centralized logging with ELK stack
4. **Metrics**: SonarQube exposes metrics via its API

## Support

For issues related to:
- **Ansible deployment**: Check this README and Ansible documentation
- **SonarQube configuration**: Refer to [SonarQube Documentation](https://docs.sonarsource.com/sonarqube/)
- **Production setup**: Consider consulting the SonarQube community or commercial support

## License

This Ansible configuration is provided under the Apache License 2.0, same as the main repository.
