#!/bin/bash

# Airflow Uninstallation Script
# This script removes Apache Airflow and all related configurations

set -e

echo "=== Airflow Uninstallation ==="
echo

# Check if we're in the correct directory
if [ ! -f "playbook.yml" ]; then
    echo "❌ Error: playbook.yml not found. Please run this script from the airflow directory."
    exit 1
fi

# Check Ansible installation
if ! command -v ansible-playbook &> /dev/null; then
    echo "❌ Error: ansible-playbook command not found. Please install Ansible."
    exit 1
fi

# Check inventory file
if [ ! -f "inventory/hosts.yml" ]; then
    echo "❌ Error: inventory/hosts.yml not found"
    exit 1
fi

echo "⚠️  This will completely remove Airflow from the target servers."
read -p "Are you sure you want to continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo
echo "🔧 Running Ansible playbook to uninstall Airflow..."
ansible-playbook -i inventory/hosts.yml uninstall.yml --ask-become-pass

echo
echo "✅ Airflow uninstallation completed!"
