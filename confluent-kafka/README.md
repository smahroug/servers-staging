# Confluent Kafka (Docker) Ansible Deployment

This directory contains Ansible scripts to deploy the **Confluent Platform Community Edition** (all components) as **Docker containers** on a target host.

## Overview

The role deploys the full Confluent stack via Docker Compose:

| Component | Image | Container | Ports (host) |
|-----------|-------|-----------|--------------|
| Kafka broker (KRaft) | `confluentinc/cp-server` | `kafka` | 9092 (internal), 9093 (Docker host) |
| Schema Registry | `confluentinc/cp-schema-registry` | `schema-registry` | 8081 |
| Kafka Connect (distributed) | `confluentinc/cp-kafka-connect` | `connect` | 8083 |
| Kafka REST Proxy | `confluentinc/cp-kafka-rest` | `kafka-rest` | 8082 |
| ksqlDB Server | `confluentinc/cp-ksqldb-server` | `ksqldb-server` | 8088 |
| Control Center Next-Gen | `confluentinc/cp-enterprise-control-center-next-gen` | `control-center` | 9021 |
| Prometheus (metrics) | `confluentinc/cp-enterprise-prometheus` | `prometheus` | 9090 |
| Alertmanager | `confluentinc/cp-enterprise-alertmanager` | `alertmanager` | 9095 (container 9093) |

Kafka runs in **KRaft mode** (no ZooKeeper) — ZooKeeper is deprecated since Confluent Platform 8.x.

> **Control Center Next-Gen** is the UI shipped with Confluent Platform 8.x (the legacy
> `cp-control-center` image was retired). It collects broker metrics through a
> **telemetry exporter** on the broker (`cp-server` image, required for the
> `TelemetryReporter` class) pushed to the Prometheus sidecar, and uses Alertmanager
> for triggers/alerts. Config files live in `/opt/confluent-kafka/config/`.

## Features

- **Docker installation**: installs Docker Engine + Compose plugin from the official Docker apt repository if not present (Ubuntu/Debian), with the `user` account added to the `docker` group
- **Latest Community Edition**: pulls the latest `confluentinc/cp-*` images (multi-arch: amd64 + arm64)
- **KRaft single-node cluster** (combined controller+broker)
- **Auto topic creation** enabled for quick start
- **Health checks** on every container + `wait_for` on the Kafka port
- **Idempotent**: re-running the playbook only applies changes
- **Uninstall playbook** that removes containers, images, volumes and config

## Directory Structure

```
confluent-kafka/
├── playbook.yml                  # Main playbook
├── uninstall.yml                 # Uninstallation playbook
├── inventory/
│   ├── hosts.yml                 # Inventory file
│   └── hosts.yml.template        # Secure inventory template
├── roles/
│   └── confluent-kafka/
│       ├── tasks/
│       │   ├── main.yml          # Orchestration
│       │   ├── docker.yml        # Docker installation (step 1)
│       │   └── kafka.yml         # Confluent Platform deployment (step 2)
│       ├── handlers/
│       │   └── main.yml          # Compose up / restart handlers
│       ├── templates/
│       │   └── docker-compose.yml.j2  # Compose file for all components
│       ├── defaults/
│       │   └── main.yml          # Default variables
│       └── vars/
│           └── main.yml          # Environment-specific overrides
├── install.sh                    # Installation script (validate + deploy)
├── uninstall.sh                  # Uninstallation script
├── validate.sh                   # Pre-deployment validation script
├── ansible.cfg                   # Ansible configuration
└── README.md                     # This file
```

## Prerequisites

- Ansible 2.9+ on the control machine with the `community.docker` collection:
  ```bash
  ansible-galaxy collection install community.docker
  ```
- Target host running Ubuntu/Debian with sudo access
- Internet access on the target host (apt + Docker Hub)
- **RAM**: 4 GB minimum, 6 GB+ recommended (Control Center is memory-hungry)

## Quick Start

### 1. Configure Inventory

Edit `inventory/hosts.yml`:

```yaml
all:
  children:
    confluent_kafka_servers:
      hosts:
        confluent-kafka:
          ansible_host: 192.168.56.5
      vars:
        ansible_user: user
        ansible_password: "user"
        ansible_become: true
        ansible_become_method: sudo
        ansible_python_interpreter: /usr/bin/python3
```

### 2. Test Connectivity

```bash
ansible -i inventory/hosts.yml confluent_kafka_servers -m ping
```

### 3. Deploy

```bash
./install.sh
# Or directly:
ansible-playbook -i inventory/hosts.yml playbook.yml --ask-become-pass --diff
```

The first run downloads the Docker packages and the Confluent images (~1.5 GB) — expect **5 to 15 minutes**.

### 4. Verify Installation

```bash
# Container status
ansible -i inventory/hosts.yml confluent_kafka_servers -m shell \
  -a "docker compose -p confluent ps"

# From your machine
open http://192.168.56.5:9021   # Control Center UI
```

Log in to Control Center with `admin` / `admin` (staging default, see `control_center_basic_user`).

## Configuration

### Default Settings (`roles/confluent-kafka/defaults/main.yml`)

- **Images**: `latest` tag (Community Edition) — pin with `confluent_version` (e.g. `"8.4.0"`)
- **Broker**: `cp-server` (Confluent Server, free) — required by the Next-Gen Control Center telemetry pipeline
- **KRaft mode**, single combined controller/broker, cluster id auto-generated
- **Listeners**: `9092` internal (plaintext), `9093` exposed on the Docker host for external clients (Flink, host tools)
- **Auto topic creation**: enabled
- **Compose project**: `confluent`, working dir `/opt/confluent-kafka`
- **Control Center Next-Gen**: port 9021, backed by Prometheus (9090) + Alertmanager (9095)
- **Firewall**: opens the Confluent ports in ufw when present

### Common Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `confluent_version` | "latest" | Confluent Platform image tag (pin e.g. "8.4.0") |
| `confluent_install_docker` | true | Install Docker if missing |
| `confluent_kafka_port_internal` | 9092 | Kafka listener inside the Docker network |
| `confluent_kafka_port_host` | 9093 | Kafka listener exposed on the VM (Docker host) |
| `confluent_schema_registry_port` | 8081 | Schema Registry |
| `confluent_kafka_rest_port` | 8082 | Kafka REST Proxy |
| `confluent_connect_enabled` | true | Deploy Kafka Connect |
| `confluent_connect_port` | 8083 | Kafka Connect REST API |
| `confluent_ksqldb_port` | 8088 | ksqlDB Server |
| `confluent_control_center_port` | 9021 | Control Center Next-Gen Web UI |
| `confluent_control_center_version` | "2.7.0" | Control Center Next-Gen image tag |
| `confluent_prometheus_port` | 9090 | Prometheus metrics UI |
| `confluent_alertmanager_port` | 9095 | Alertmanager (host port; container listens on 9093) |
| `confluent_kafka_heap` | "1G" | Kafka broker heap |
| `confluent_ksqldb_heap` | "1G" | ksqlDB heap |
| `confluent_control_center_heap` | "1200M" | Control Center heap |
| `confluent_compose_project` | "confluent" | Docker Compose project name |
| `confluent_compose_dir` | /opt/confluent-kafka | Where the compose file lives |
| `confluent_start_services` | true | Start containers after install |
| `confluent_cluster_id` | generated | KRaft cluster id (stable across runs) |

## Component URLs & Ports (application access)

All components are reachable from the Mac, other staging VMs and applications via the
VM host-only IP (default **`192.168.56.5`** — see the ⚠️ note below).

| Component | URL / endpoint | Port | Auth | Typical use |
|-----------|----------------|------|------|-------------|
| **Kafka broker** (external) | `192.168.56.5:9093` | 9093 | PLAINTEXT | `bootstrap-server` for producers/consumers, Flink, ksqldb-cli, Kafka tools |
| **Kafka broker** (internal) | `kafka:9092` | 9092 | PLAINTEXT | Container-to-container only (compose network) — **not** reachable from outside |
| **Schema Registry** | `http://192.168.56.5:8081` | 8081 | none | Avro/JSON schema management (`/subjects`, `/schemas/ids/{id}`) |
| **Kafka Connect** | `http://192.168.56.5:8083` | 8083 | none | Connect REST API (`/connectors`, `/connector-plugins`) |
| **Kafka REST Proxy** | `http://192.168.56.5:8082` | 8082 | none | Produce/consume over HTTP (`/v3/clusters`) |
| **ksqlDB Server** | `http://192.168.56.5:8088` | 8088 | none | ksql queries (`/info`, `/query`, websocket `/query.ws`) |
| **Control Center Next-Gen** | `http://192.168.56.5:9021` | 9021 | `admin` / `admin` | Web UI (clusters, topics, consumers, Connect, ksqlDB) |
| **Prometheus** | `http://192.168.56.5:9090` | 9090 | none | Broker metrics, PromQL queries (`/api/v1/query`), targets |
| **Alertmanager** | `http://192.168.56.5:9095` | 9095 | none | Alerts UI/API (container listens on 9093, host port 9095) |

> ⚠️ **The VM IP can change.** The `192.168.56.x` address depends on the order VMs are
> started (VirtualBox DHCP). If the IP changes:
> 1. Update `ansible_host` in `inventory/hosts.yml`
> 2. Re-run the playbook — it re-renders the compose file with the new advertised host
>    (`confluent_advertised_host`, defaults to `ansible_host`) and restarts the stack
>
> Kafka clients resolve the broker through the **advertised listener** baked into the
> compose file, so a stale IP breaks *new* client connections until the playbook re-runs.
> Internal component traffic (C3 ↔ SR ↔ Connect ↔ ksqlDB ↔ broker) uses Docker DNS names
> (`kafka`, `schema-registry`, ...) and is unaffected.

### Client configuration examples

**Kafka producer/consumer (Java, Spring, Flink, ...):**
```properties
bootstrap.servers=192.168.56.5:9093
# PLAINTEXT, no auth — staging only
```

**Schema Registry (Avro serializer):**
```properties
schema.registry.url=http://192.168.56.5:8081
```

**Kafka Connect (REST):**
```bash
curl http://192.168.56.5:8083/connectors
curl -X POST http://192.168.56.5:8083/connectors \
  -H "Content-Type: application/json" \
  -d '{"name": "my-connector", "config": {...}}'
```

**ksqlDB:**
```bash
curl -X POST http://192.168.56.5:8088/query \
  -H "Content-Type: application/vnd.ksql.v1+json" \
  -d '{"ksql": "SHOW TOPICS;", "streamsProperties": {}}'
```

**Kafka REST Proxy (v3):**
```bash
curl http://192.168.56.5:8082/v3/clusters
```

**CLI quick checks from the Mac / another VM:**
```bash
# Kafka (PLAINTEXT)
kafka-topics --bootstrap-server 192.168.56.5:9093 --list

# Schema Registry
curl http://192.168.56.5:8081/subjects

# ksqlDB
curl http://192.168.56.5:8088/info

# REST Proxy
curl http://192.168.56.5:8082/v3/clusters

# Connect
curl http://192.168.56.5:8083/connector-plugins
```

### Ports inside the VM only (not exposed)

| Service | Port | Note |
|---------|------|------|
| Kafka internal listener | 9092 | Compose network only |
| KRaft controller | 9094 | Compose network only |
| Kafka JMX | 9101 | Compose network only |
| Alertmanager (container) | 9093 | Published on host as 9095 |

## Service Management

```bash
# On the VM
cd /opt/confluent-kafka
docker compose -p confluent ps
docker compose -p confluent restart kafka
docker compose -p confluent down      # keeps volumes
docker compose -p confluent down -v   # removes data

# Logs
docker compose -p confluent logs -f kafka
docker logs kafka 2>&1 | tail -50
```

## Uninstallation

```bash
./uninstall.sh
# Or directly:
ansible-playbook -i inventory/hosts.yml uninstall.yml --ask-become-pass
```

Removes the compose stack (containers + volumes), `/opt/confluent-kafka` and the pulled Confluent images. Docker itself is **kept** (set `docker_remove_packages: true` in `uninstall.yml` to also remove Docker).

## Security Considerations

- Default listeners are **PLAINTEXT** — staging only. For production add SASL/SSL listeners and credentials
- Default Control Center login `admin/admin` — override `control_center_basic_user` / `control_center_basic_password`
- Use SSH keys + ansible-vault instead of plain passwords in the inventory

## Troubleshooting

1. **`docker` permission denied**: re-login after the role adds `user` to the `docker` group (the playbook handles this via `ansible_user` + sudo)
2. **Kafka not reachable on 9093**: check `docker compose -p confluent ps` and `docker logs kafka`
3. **Control Center slow/OOM**: increase `confluent_control_center_heap` or VM RAM
4. **ARM64 (Apple Silicon host)**: all `cp-*` images used here are multi-arch (amd64 + arm64)

## Support

- [Confluent Platform Docker docs](https://docs.confluent.io/platform/current/installation/docker/installation.html)
- [cp-kafka image reference](https://hub.docker.com/r/confluentinc/cp-kafka)

## License

Provided under the Apache License 2.0, same as the main repository.
