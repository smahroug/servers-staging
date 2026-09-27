# Kafka Ansible Deployment

This directory contains Ansible scripts to deploy Apache Kafka on a target host in **KRaft mode** (no ZooKeeper required), with a single combined broker + controller node.

## Overview

Apache Kafka is a distributed event streaming platform. This Ansible playbook automates the installation and configuration of a single-broker Kafka cluster using the built-in KRaft consensus protocol (Kafka 3.x), which removes the need to install and manage ZooKeeper.

## Features

- **Smart Java Detection**: Automatically detects existing Java installations and only installs Java 21 if needed
- Downloads and installs Apache Kafka (KRaft mode, no ZooKeeper)
- Configures a single combined broker + controller node
- Formats KRaft storage automatically (generates a cluster ID on first run)
- Creates a systemd service for automatic startup
- Configurable listeners, partitions, retention and heap settings
- Security hardened systemd service configuration
- Log rotation configuration
- **Dynamic JAVA_HOME Configuration**: Automatically configures JAVA_HOME based on detected Java installation

## Directory Structure

```
kafka/
├── playbook.yml              # Main playbook
├── uninstall.yml             # Uninstallation playbook
├── install.sh                # Installation script (validate + deploy)
├── uninstall.sh              # Uninstallation script
├── validate.sh               # Pre-deployment validation script
├── ansible.cfg               # Ansible configuration
├── inventory/
│   ├── hosts.yml             # Inventory file
│   └── hosts.yml.template    # Inventory template
├── roles/
│   └── kafka/
│       ├── tasks/
│       │   └── main.yml      # Main installation tasks
│       ├── handlers/
│       │   └── main.yml      # Service handlers
│       ├── templates/
│       │   ├── server.properties.j2   # Kafka broker configuration template
│       │   ├── kafka.service.j2       # Systemd service template
│       │   └── log4j.properties.j2    # Logging configuration template
│       ├── vars/
│       │   └── main.yml      # Environment-specific variables
│       └── defaults/
│           └── main.yml      # Default variables
├── vars-examples/
│   ├── development.yml       # Development profile
│   └── production.yml        # Production profile
└── README.md                 # This file
```

## Prerequisites

- Ansible 2.9+ installed on the control machine
- Target host running Ubuntu/Debian (tested on Ubuntu 20.04+)
- SSH access to the target host with sudo privileges
- Python 3 installed on the target host

## Quick Start

### 1. Configure Inventory

Edit `inventory/hosts.yml` with your server details:

```yaml
all:
  children:
    kafka_servers:
      hosts:
        kafka-broker-1:
          ansible_host: 192.168.56.3
          kafka_role: broker
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

Select and customize a configuration profile:

```bash
# For development
cp vars-examples/development.yml roles/kafka/vars/main.yml

# For production
cp vars-examples/production.yml roles/kafka/vars/main.yml
```

### 3. Test Connectivity

```bash
ansible -i inventory/hosts.yml kafka_servers -m ping
```

### 4. Deploy Kafka

```bash
# Run installation script with validation
./install.sh

# Or run directly with additional options
ansible-playbook -i inventory/hosts.yml playbook.yml --ask-become-pass --diff
```

### 5. Verify Installation

```bash
# Check service status
ansible -i inventory/hosts.yml kafka_servers -m shell -a "systemctl status kafka"

# View logs
ansible -i inventory/hosts.yml kafka_servers -m shell -a "tail -f /var/log/kafka/server.log"
```

## Configuration

### Default Settings

The role comes with sensible defaults in `roles/kafka/defaults/main.yml`:

- **Kafka Version**: 3.7.0 (Scala 2.13)
- **Mode**: KRaft (single combined broker + controller, no ZooKeeper)
- **Java Version**: OpenJDK 21
- **Heap**: 512m min / 1G max
- **Partitions**: 1 default partition
- **Replication factor**: 1 (single broker)
- **Retention**: 7 days

### Common Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `kafka_version` | "3.7.0" | Kafka version to install |
| `kafka_scala_version` | "2.13" | Scala version of the binary |
| `kafka_node_id` | 0 | KRaft node ID |
| `kafka_cluster_id` | "" | Cluster ID (auto-generated if empty) |
| `kafka_port` | 9092 | Broker listener port |
| `kafka_controller_port` | 9093 | KRaft controller port |
| `kafka_advertised_host_override` | "" | Advertised host for clients (auto-detected if empty) |
| `kafka_num_partitions` | 1 | Default number of partitions |
| `kafka_log_retention_hours` | 168 | Log retention in hours |
| `kafka_heap_opts` | "-Xms512m -Xmx1G" | JVM heap settings |
| `kafka_auto_create_topics_enable` | true | Auto-create topics |

### Advertised Listeners

The `advertised.listeners` setting is what clients use to connect. By default, the role advertises the `ansible_host` from the inventory (e.g. `192.168.56.3`), falling back to the host's default IPv4 address. If clients reach the broker through a different address (NAT, DNS name, load balancer), set:

```yaml
kafka_advertised_host_override: "kafka.example.com"
```

## Network Ports

| Service | Port | Description |
|---------|------|-------------|
| Kafka broker (PLAINTEXT) | 9092 | Client connections |
| KRaft controller | 9093 | Internal controller quorum |
| JMX | 9999 | Metrics (if enabled) |

Ensure these ports are open in your firewall configuration.

## Service Management

```bash
# Start Kafka
sudo systemctl start kafka

# Stop Kafka
sudo systemctl stop kafka

# Check status
sudo systemctl status kafka

# View logs
journalctl -u kafka -f
```

## Basic Usage

```bash
# Create a topic
/opt/kafka/bin/kafka-topics.sh --create \
  --topic test \
  --partitions 1 --replication-factor 1 \
  --bootstrap-server localhost:9092

# List topics
/opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092

# Produce messages
/opt/kafka/bin/kafka-console-producer.sh --topic test --bootstrap-server localhost:9092

# Consume messages
/opt/kafka/bin/kafka-console-consumer.sh --topic test --from-beginning --bootstrap-server localhost:9092
```

## Uninstallation

```bash
./uninstall.sh
# Or directly:
ansible-playbook -i inventory/hosts.yml uninstall.yml --ask-become-pass
```

This removes the Kafka service, installation, data (including KRaft metadata and topic data), logs, log rotation config, and the `kafka` user/group.

## Security Considerations

- The systemd service runs with security hardening (`NoNewPrivileges`, `ProtectSystem`, etc.)
- Kafka runs as a dedicated `kafka` user with minimal privileges
- The default deployment uses PLAINTEXT (unencrypted, unauthenticated) listeners
- For production, consider enabling SASL/TLS (SSL) listeners and storing credentials in Ansible Vault
- Use SSH key-based authentication instead of passwords

## Troubleshooting

### Common Issues

1. **Java not found**: The playbook automatically detects existing Java installations. You can override with the `java_home` variable.
2. **Broker fails to start**: Check `/var/log/kafka/server.log` and `journalctl -u kafka`
3. **Clients can't connect**: Verify `advertised.listeners` matches the address clients use (see Advertised Listeners section)
4. **Storage format errors**: If KRaft metadata is corrupted, stop the service, remove `/var/lib/kafka`, and re-run the playbook (this deletes all topic data)

### Verification Commands

```bash
# Check if Kafka is running
ps aux | grep kafka

# Check listener port
ss -tlnp | grep 9092

# Check broker logs
tail -f /var/log/kafka/server.log
```

## Support

For issues related to:
- **Ansible deployment**: Check this README and Ansible documentation
- **Kafka configuration**: Refer to [Apache Kafka Documentation](https://kafka.apache.org/documentation/)

## License

This Ansible configuration is provided under the Apache License 2.0, same as the main repository.
