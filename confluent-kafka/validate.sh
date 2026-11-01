#!/bin/bash

# Confluent Kafka (Docker) Deployment Validation Script
# This script helps validate the Ansible deployment setup

set -e

echo "=== Confluent Kafka Ansible Deployment Validation ==="
echo

# Check if we're in the correct directory
if [ ! -f "playbook.yml" ]; then
    echo "❌ Error: playbook.yml not found. Please run this script from the confluent-kafka directory."
    exit 1
fi

echo "✅ Playbook file found"

# Check Ansible installation
if ! command -v ansible-playbook &> /dev/null; then
    echo "❌ Error: ansible-playbook command not found. Please install Ansible."
    exit 1
fi

echo "✅ Ansible is installed"

# Check community.docker collection
if ansible-galaxy collection list 2>/dev/null | grep -q "community.docker"; then
    echo "✅ community.docker collection is installed"
else
    echo "⚠️  community.docker collection not found (not required: the role uses command/docker CLI)"
fi

# Validate playbook syntax
echo "🔍 Validating playbook syntax..."
if ansible-playbook --syntax-check playbook.yml; then
    echo "✅ Playbook syntax is valid"
else
    echo "❌ Playbook syntax validation failed"
    exit 1
fi

# Check inventory file
if [ ! -f "inventory/hosts.yml" ]; then
    echo "❌ Error: inventory/hosts.yml not found"
    exit 1
fi

echo "✅ Inventory file found"

# Check role structure
required_dirs=("roles/confluent-kafka/tasks" "roles/confluent-kafka/handlers" "roles/confluent-kafka/templates" "roles/confluent-kafka/defaults" "roles/confluent-kafka/vars")
for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo "✅ Directory $dir exists"
    else
        echo "❌ Required directory $dir is missing"
        exit 1
    fi
done

# Check required files
required_files=(
    "roles/confluent-kafka/tasks/main.yml"
    "roles/confluent-kafka/tasks/docker.yml"
    "roles/confluent-kafka/tasks/kafka.yml"
    "roles/confluent-kafka/handlers/main.yml"
    "roles/confluent-kafka/templates/docker-compose.yml.j2"
    "roles/confluent-kafka/defaults/main.yml"
    "roles/confluent-kafka/vars/main.yml"
)
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ File $file exists"
    else
        echo "❌ Required file $file is missing"
        exit 1
    fi
done

echo
echo "🎉 All validation checks passed!"
echo
echo "Next steps:"
echo "1. Configure your inventory in inventory/hosts.yml with actual server IPs"
echo "2. Test connectivity: ansible -i inventory/hosts.yml confluent_kafka_servers -m ping"
echo "3. Run the playbook: ansible-playbook -i inventory/hosts.yml playbook.yml"
echo "4. Control Center UI: http://<confluent-host>:9021 (default login: admin / admin)"
echo
