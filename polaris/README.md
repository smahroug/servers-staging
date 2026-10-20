# Apache Polaris Ansible Deployment

This directory contains Ansible scripts to deploy Apache Polaris on target hosts.

## Overview

Apache Polaris is an open-source, fully-featured catalog implementation for Apache Iceberg™. This Ansible playbook automates the installation and configuration of Polaris on target servers.

## Features

- **Smart Java Detection**: Automatically detects existing Java installations and only installs Java 21 if needed
- Downloads and installs Apache Polaris
- Configures Polaris server (Dropwizard-based configuration)
- Creates a systemd service for automatic startup
- Configurable persistence (in-memory or EclipseLink)
- Security hardened systemd service configuration
- **Dynamic JAVA_HOME Configuration**: Automatically configures JAVA_HOME based on detected Java installation
- **ARM64 support**: Automatically detects the target architecture (aarch64/amd64)

## Directory Structure

```
polaris/
├── playbook.yml              # Main playbook
├── uninstall.yml             # Uninstallation playbook
├── inventory/
│   └── hosts.yml             # Inventory file
├── roles/
│   └── polaris/
│       ├── tasks/
│       │   └── main.yml      # Main installation tasks
│       ├── handlers/
│       │   └── main.yml      # Service handlers
│       ├── templates/
│       │   ├── application.properties.j2  # Polaris configuration template
│       │   └── polaris.service.j2         # Systemd service template
│       ├── vars/
│       │   └── main.yml      # Environment-specific variables
│       └── defaults/
│           └── main.yml      # Default variables
├── install.sh                # Installation script
├── uninstall.sh              # Uninstallation script
├── validate.sh               # Validation script
├── ansible.cfg               # Ansible configuration
└── README.md                 # This file
```

## Prerequisites

- Ansible 2.9+ installed on the control machine
- Target hosts running Ubuntu/Debian (tested on Ubuntu 20.04+)
- SSH access to target hosts with sudo privileges
- Python 3 installed on target hosts
- `sshpass` installed on the control machine (for password authentication)

## Quick Start

### 1. Configure Inventory

Edit `inventory/hosts.yml` with your server details:

```yaml
all:
  children:
    polaris_servers:
      hosts:
        polaris-server:
          ansible_host: 192.168.56.4
      vars:
        ansible_user: user
        ansible_password: "user"
        ansible_become: true
        ansible_become_method: sudo
```

### 2. Test Connectivity
```bash
ansible -i inventory/hosts.yml polaris_servers -m ping
```

### 3. Deploy Polaris
```bash
# Run installation script with validation
./install.sh

# Or run directly with additional options
ansible-playbook -i inventory/hosts.yml playbook.yml --ask-become-pass --diff
```

### 4. Verify Installation
- Access Polaris API: `http://192.168.56.4:8181/api/catalog/v1/config`
- Check service status: `systemctl status polaris`
- View logs: `tail -f /var/log/polaris/polaris.log`

## Configuration

### Default Settings

The role comes with sensible defaults in `roles/polaris/defaults/main.yml`:

- **Polaris Version**: 1.2.0
- **Java Version**: OpenJDK 21
- **HTTP Port**: 8181
- **Admin Port**: 1000
- **Persistence**: in-memory (for development)
- **JVM Heap**: 1024m

### Customization

Override default variables in `roles/polaris/vars/main.yml` or pass them during playbook execution:

```bash
ansible-playbook -i inventory/hosts.yml playbook.yml \
  -e "polaris_jvm_heap_size=2048m" \
  -e "polaris_http_port=8182"
```

### Common Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `polaris_version` | "1.2.0" | Polaris version to install |
| `polaris_http_port` | 8181 | Polaris HTTP API port |
| `polaris_admin_port` | 1000 | Dropwizard admin port |
| `polaris_persistence_type` | "in-memory" | Persistence type (in-memory or eclipselink) |
| `polaris_jvm_heap_size` | "1024m" | JVM max heap size |
| `polaris_log_level` | "INFO" | Logging level |

## Network Ports

| Service | Port | Description |
|---------|------|-------------|
| Polaris API | 8181 | Iceberg REST catalog API |
| Polaris Admin | 1000 | Dropwizard admin endpoints |
| Polaris Metrics | 8182 | Metrics endpoint |

Ensure these ports are open in your firewall configuration.

## Service Management

```bash
# Start Polaris
sudo systemctl start polaris

# Stop Polaris
sudo systemctl stop polaris

# Check status
sudo systemctl status polaris

# View logs
journalctl -u polaris -f
```

## Troubleshooting

### Common Issues

1. **Java not found**: The playbook automatically detects existing Java installations and installs OpenJDK 21 if needed
2. **Permission denied**: Check that the `polaris` user has proper permissions
3. **Network connectivity**: Verify firewall settings and network connectivity
4. **Memory issues**: Adjust `polaris_jvm_heap_size` based on your server specifications

### Log Locations

- Polaris logs: `/var/log/polaris/`
- Systemd service logs: `journalctl -u polaris`

## Security Considerations

- The systemd service runs with security hardening (`NoNewPrivileges`, `ProtectSystem`, etc.)
- Polaris runs as a dedicated `polaris` user with minimal privileges
- Use SSH key-based authentication instead of passwords in production
- Store sensitive variables in Ansible Vault

## Support

For issues related to:
- **Ansible deployment**: Check this README and Ansible documentation
- **Polaris configuration**: Refer to [Apache Polaris Documentation](https://polaris.apache.org/)

## License

This Ansible configuration is provided under the Apache License 2.0, same as the main repository.

