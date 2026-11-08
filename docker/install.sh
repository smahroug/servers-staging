#!/bin/bash
set -e

echo "========================================="
echo "  Docker Ansible Deployment"
echo "========================================="
echo ""

echo "🔍 Step 1/3: Validating project structure..."
sh validate.sh

echo ""
echo "🚀 Step 2/3: Running Ansible playbook..."
echo "   Inventory : inventory/hosts.yml"
echo "   Playbook  : playbook.yml"
echo "-----------------------------------------"
echo ""

ansible-playbook -i inventory/hosts.yml playbook.yml -vv

echo ""
echo "========================================="
echo "✅ Docker deployment completed!"
echo "   Target: 192.168.56.10"
echo "   Test:   ssh user@192.168.56.10 'docker run hello-world'"
echo "========================================="
