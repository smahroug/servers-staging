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

# Run the playbook with enhanced options
ansible-playbook -i inventory/hosts.yml playbook.yml \
  --ask-become-pass \
  --diff \
  --check-mode || {
  
  echo "❌ Dry run failed. Please check the errors above."
  echo "To proceed anyway, run:"
  echo "ansible-playbook -i inventory/hosts.yml playbook.yml --ask-become-pass"
  exit 1
}

echo ""
echo "✅ Dry run successful!"
echo ""
echo "To execute the deployment, run:"
echo "ansible-playbook -i inventory/hosts.yml playbook.yml --ask-become-pass"
echo ""
echo "For production deployment with vault:"
echo "ansible-playbook -i inventory/hosts.yml playbook.yml --ask-vault-pass"