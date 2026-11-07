#!/bin/bash

# Confluent Kafka (Docker) Deployment Installation Script
# This script validates the configuration and deploys the Confluent Platform

set -e

echo "=== Starting Confluent Kafka Deployment ==="

# Run validation first
echo "🔍 Running pre-deployment validation..."
./validate.sh

echo ""
echo "🚀 Starting Confluent Kafka deployment..."

# Run the playbook
ansible-playbook -i inventory/hosts.yml playbook.yml \
  --ask-become-pass \
  --diff || {

  echo "❌ Deployment failed. Please check the errors above."
  exit 1
}

echo ""
echo "✅ Confluent Kafka deployment completed!"
echo "   Control Center: http://<confluent-host>:9021 (default login: admin / admin)"
echo "   Kafka (external): <confluent-host>:9093"
echo "   PostgreSQL (external): <confluent-host>:5432 (default login: postgres / postgres)"
