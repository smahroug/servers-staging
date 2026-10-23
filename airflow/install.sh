#!/bin/bash

# Airflow Deployment Installation Script
# This script validates the configuration and deploys Apache Airflow (scheduler + webserver UI)

set -e

echo "=== Starting Airflow Deployment ==="

# Run validation first
echo "🔍 Running pre-deployment validation..."
./validate.sh

echo ""
echo "🚀 Starting Airflow deployment..."

# Run the playbook
ansible-playbook -i inventory/hosts.yml playbook.yml \
  --ask-become-pass \
  --diff || {

  echo "❌ Deployment failed. Please check the errors above."
  exit 1
}

echo ""
echo "✅ Airflow deployment completed!"
echo "   Web UI: http://<airflow-host>:8080 (default login: admin / admin)"

