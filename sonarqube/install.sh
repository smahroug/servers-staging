#!/bin/bash
set -e

echo "========================================="
echo "  SonarQube Ansible Deployment"
echo "========================================="
echo ""

echo "🔍 Step 1/4: Installing Python dependencies..."
pip3 install psycopg2-binary 2>/dev/null || echo "⚠️  psycopg2-binary already installed or pip3 not available"

echo ""
echo "🔍 Step 2/4: Installing Ansible collections..."
ansible-galaxy collection install -r requirements.yml

echo ""
echo "🔍 Step 3/4: Validating project structure..."
sh validate.sh

echo ""
echo "🚀 Step 4/4: Running Ansible playbook..."
echo "   Inventory : inventory/hosts.yml"
echo "   Playbook  : playbook.yml"
echo "-----------------------------------------"
echo ""

ansible-playbook -i inventory/hosts.yml playbook.yml -vvv

echo ""
echo "========================================="
echo "✅ SonarQube deployment completed!"
echo "   Access: http://192.168.178.43:9000"
echo "========================================="
