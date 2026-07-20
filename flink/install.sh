#!/bin/bash

# Flink Deployment Installation Script
# This script validates the configuration and deploys Flink

set -e

echo "=== Starting Flink Deployment ==="

# Run validation first
echo "🔍 Running pre-deployment validation..."
./validate.sh

echo ""
echo "🚀 Starting Flink deployment..."

# Run the playbook
ansible-playbook -i inventory/hosts.yml playbook.yml \
  --ask-become-pass \
  --diff || {

  echo "❌ Deployment failed. Please check the errors above."
  exit 1
}

echo ""
echo "✅ Flink deployment completed!"
