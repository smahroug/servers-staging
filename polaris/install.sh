#!/bin/bash

# Apache Polaris Deployment Installation Script
# This script validates the configuration and deploys Polaris

set -e

echo "=== Starting Apache Polaris Deployment ==="

# Run validation first
echo "🔍 Running pre-deployment validation..."
./validate.sh

echo ""
echo "🚀 Starting Apache Polaris deployment..."

# Run the playbook
ansible-playbook -i inventory/hosts.yml playbook.yml \
  --ask-become-pass \
  --diff || {

  echo "❌ Deployment failed. Please check the errors above."
  exit 1
}

echo ""
echo "✅ Apache Polaris deployment completed!"
