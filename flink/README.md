# Flink Ansible Deployment

This directory contains Ansible scripts to deploy Apache Flink on target hosts in a standalone cluster mode.

## Overview

Apache Flink is a framework and distributed processing engine for stateful computations over unbounded and bounded data streams. This Ansible playbook automates the installation and configuration of Flink on multiple servers.

## Features

- **Smart Java Detection**: Automatically detects existing Java installations and only installs Java 11 if needed
- Downloads and installs Apache Flink
- Configures Flink cluster (standalone mode)
- Creates systemd services for automatic startup
- Supports both JobManager (master) and TaskManager (worker) nodes
- Configurable memory settings and cluster parameters
- Security hardened systemd service configuration
- **Dynamic JAVA_HOME Configuration**: Automatically configures JAVA_HOME based on detected Java installation

## Directory Structure

```
flink/
├── playbook.yml              # Main playbook
├── inventory/
│   └── hosts.yml             # Inventory file example
├── roles/
│   └── flink/
│       ├── tasks/
│       │   └── main.yml      # Main installation tasks
│       ├── handlers/
│       │   └── main.yml      # Service handlers
│       ├── templates/
│       │   ├── flink-conf.yaml.j2    # Flink configuration template
│       │   └── flink.service.j2      # Systemd service template
│       ├── vars/
│       │   └── main.yml      # Environment-specific variables
│       └── defaults/
│           └── main.yml      # Default variables
└── README.md                 # This file
```

## Prerequisites

- Ansible 2.9+ installed on the control machine
- Target hosts running Ubuntu/Debian (tested on Ubuntu 20.04+)
- SSH access to target hosts with sudo privileges
- Python 3 installed on target hosts

## Quick Start

1. **Configure Inventory**: Edit `inventory/hosts.yml` with your server details:
   ```yaml
   all:
     children:
       flink_servers:
         hosts:
           flink-master:
             ansible_host: your-master-ip
             flink_role: master
           flink-worker-1:
             ansible_host: your-worker-ip-1
             flink_role: worker
           flink-worker-2:
             ansible_host: your-worker-ip-2
             flink_role: worker
   ```

2. **Test Connectivity**:
   ```bash
   ansible -i inventory/hosts.yml flink_servers -m ping
   ```

3. **Deploy Flink**:
   ```bash
   ansible-playbook -i inventory/hosts.yml playbook.yml
   ```

4. **Verify Installation**:
   - Access Flink Web UI: `http://your-master-ip:8081`
   - Check service status: `systemctl status flink`

## Configuration

### Default Settings

The role comes with sensible defaults in `roles/flink/defaults/main.yml`:

- **Flink Version**: 1.18.1
- **Scala Version**: 2.12
- **Java Version**: OpenJDK 11
- **Memory Settings**:
  - JobManager heap: 1024m
  - TaskManager process memory: 1728m
  - TaskManager Flink memory: 1280m
- **Parallelism**: 1 (default)
- **Task Slots**: 1 per TaskManager

### Customization

Override default variables in `roles/flink/vars/main.yml` or pass them during playbook execution:

```bash
ansible-playbook -i inventory/hosts.yml playbook.yml \
  -e "flink_jobmanager_heap_size=2048m" \
  -e "flink_taskmanager_memory_process_size=4096m"
```

### Common Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `flink_version` | "1.18.1" | Flink version to install |
| `flink_jobmanager_heap_size` | "1024m" | JobManager JVM heap size |
| `flink_taskmanager_memory_process_size` | "1728m" | TaskManager total memory |
| `flink_parallelism_default` | 1 | Default parallelism for jobs |
| `flink_taskmanager_numberOfTaskSlots` | 1 | Number of task slots per TaskManager |
| `flink_checkpointing_interval` | "10000" | Checkpoint interval in ms |

## Java Detection and Installation

The playbook includes intelligent Java detection that:

- **Detects existing Java installations** using `which java` command and common installation paths
- **Supports multiple Java distributions**: OpenJDK, Oracle JDK, Temurin, Amazon Corretto, etc.
- **Only installs Java if needed**: Skips Java installation if a compatible version is already present
- **Automatically configures JAVA_HOME**: Uses detected Java installation path in Flink configuration
- **Fallback installation**: Installs OpenJDK 11 if no Java is found

### Java Detection Paths

The playbook checks these common Java installation locations:
- `/usr/lib/jvm/java-11-openjdk-amd64`
- `/usr/lib/jvm/java-8-openjdk-amd64`
- `/usr/lib/jvm/default-java`
- `/opt/java`
- `/usr/java/latest`

You can override the Java detection by setting `java_home` variable explicitly.

## Network Ports

| Service | Port | Description |
|---------|------|-------------|
| JobManager RPC | 6123 | Internal communication |
| Web UI | 8081 | Flink dashboard |
| TaskManager Data | 6121-6125 | Data exchange (dynamic) |

Ensure these ports are open in your firewall configuration.

## Service Management

### Start/Stop Services

```bash
# Start Flink cluster
sudo systemctl start flink

# Stop Flink cluster
sudo systemctl stop flink

# Check status
sudo systemctl status flink

# View logs
journalctl -u flink -f
```

### Manual Start/Stop (Alternative)

```bash
# Start cluster (on master node)
sudo -u flink /opt/flink/bin/start-cluster.sh

# Stop cluster (on master node)
sudo -u flink /opt/flink/bin/stop-cluster.sh

# Start TaskManager only (on worker nodes)
sudo -u flink /opt/flink/bin/taskmanager.sh start

# Stop TaskManager only (on worker nodes)
sudo -u flink /opt/flink/bin/taskmanager.sh stop
```

## Troubleshooting

### Common Issues

1. **Java not found**: The playbook automatically detects existing Java installations. If you encounter Java issues:
   - Check detected Java path: `ansible-playbook -i inventory/hosts.yml playbook.yml --tags flink -v`
   - Manually verify Java: `java -version` and `echo $JAVA_HOME`
   - The playbook supports OpenJDK, Oracle JDK, and other Java distributions
2. **Permission denied**: Check that the `flink` user has proper permissions
3. **Network connectivity**: Verify firewall settings and network connectivity between nodes
4. **Memory issues**: Adjust memory settings based on your server specifications

### Log Locations

- Flink logs: `/var/log/flink/`
- Systemd service logs: `journalctl -u flink`
- Application logs: `/opt/flink/log/`

### Verification Commands

```bash
# Check if Flink is running
ps aux | grep flink

# Check network connectivity
netstat -tlnp | grep 6123

# Test cluster health
/opt/flink/bin/flink list

# Submit a test job
/opt/flink/bin/flink run /opt/flink/examples/streaming/WordCount.jar
```

## Security Considerations

- The systemd service runs with security hardening (`NoNewPrivileges`, `PrivateTmp`, etc.)
- Flink runs as a dedicated `flink` user with minimal privileges
- Consider enabling Kerberos authentication for production environments
- Use TLS/SSL for web UI in production deployments

## High Availability

For production deployments, consider:

1. **Enable HA mode**: Set `flink_high_availability: true`
2. **Configure ZooKeeper**: Set up ZooKeeper cluster for coordination
3. **Shared storage**: Use HDFS or S3 for state storage
4. **Load balancer**: Use a load balancer for JobManager endpoints

Example HA configuration:
```yaml
flink_high_availability: true
flink_high_availability_storageDir: "hdfs://namenode:port/flink/ha/"
```

## Monitoring

Monitor your Flink cluster using:

1. **Flink Web UI**: Built-in dashboard at `http://jobmanager:8081`
2. **Metrics**: Export metrics to external systems (Prometheus, InfluxDB)
3. **Logging**: Centralized logging with ELK stack
4. **System monitoring**: Monitor CPU, memory, and disk usage

## Support

For issues related to:
- **Ansible deployment**: Check this README and Ansible documentation
- **Flink configuration**: Refer to [Apache Flink Documentation](https://flink.apache.org/docs/)
- **Production setup**: Consider consulting the Flink community or commercial support

## License

This Ansible configuration is provided under the Apache License 2.0, same as the main repository.