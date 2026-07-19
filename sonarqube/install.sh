#!/bin/bash
set -e

echo "========================================="
echo "  SonarQube Ansible Deployment"
echo "========================================="
echo ""

echo "🔍 Step 1/2: Validating project structure..."
sh validate.sh

echo ""
echo "🚀 Step 2/2: Running Ansible playbook..."
echo "   Inventory : inventory/hosts.yml"
echo "   Playbook  : playbook.yml"
echo "-----------------------------------------"
echo ""

ansible-playbook -i inventory/hosts.yml playbook.yml -vvv

echo ""
echo "========================================="
echo "✅ SonarQube deployment completed!"
echo "   Access: http://172.16.100.140:9000"
echo "========================================="
