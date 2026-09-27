#!/bin/bash

# Kafka Deployment Installation Script
# This script validates the configuration and deploys Kafka

set -e

echo "=== Starting Kafka Deployment ==="

# Run validation first
echo "🔍 Running pre-deployment validation..."
./validate.sh

echo ""
echo "🚀 Starting Kafka deployment..."

# Run the playbook
ansible-playbook -i inventory/hosts.yml playbook.yml \
  --ask-become-pass \
  --diff || {

  echo "❌ Deployment failed. Please check the errors above."
  exit 1
}

echo ""
echo "✅ Kafka deployment completed!"
