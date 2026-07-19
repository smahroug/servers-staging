#!/bin/bash

# SonarQube Uninstallation Script
# This script removes SonarQube and all related configurations

set -e

echo "=== SonarQube Uninstallation ==="
echo

# Check if we're in the correct directory
if [ ! -f "playbook.yml" ]; then
    echo "❌ Error: playbook.yml not found. Please run this script from the sonarqube directory."
    exit 1
fi

echo "⚠️  This will completely remove SonarQube from the target servers."
read -p "Are you sure you want to continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo
echo "🔧 Running Ansible playbook to uninstall SonarQube..."
ansible-playbook -i inventory/hosts.yml uninstall.yml

echo
echo "✅ SonarQube uninstallation completed!"
