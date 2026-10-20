#!/bin/bash

# Apache Polaris Deployment Validation Script
# This script helps validate the Ansible deployment setup

set -e

echo "=== Apache Polaris Ansible Deployment Validation ==="
echo

# Check if we're in the correct directory
if [ ! -f "playbook.yml" ]; then
    echo "❌ Error: playbook.yml not found. Please run this script from the polaris directory."
    exit 1
fi

echo "✅ Playbook file found"

# Check Ansible installation
if ! command -v ansible-playbook &> /dev/null; then
    echo "❌ Error: ansible-playbook command not found. Please install Ansible."
    exit 1
fi

echo "✅ Ansible is installed"

# Validate playbook syntax
echo "🔍 Validating playbook syntax..."
if ansible-playbook --syntax-check playbook.yml; then
    echo "✅ Playbook syntax is valid"
else
    echo "❌ Playbook syntax validation failed"
    exit 1
fi

# Check inventory file
if [ ! -f "inventory/hosts.yml" ]; then
    echo "❌ Error: inventory/hosts.yml not found"
    exit 1
fi

echo "✅ Inventory file found"


# Check role structure
required_dirs=("roles/polaris/tasks" "roles/polaris/handlers" "roles/polaris/templates" "roles/polaris/defaults" "roles/polaris/vars")
for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo "✅ Directory $dir exists"
    else
        echo "❌ Required directory $dir is missing"
        exit 1
    fi
done

# Check required files
required_files=("roles/polaris/tasks/main.yml" "roles/polaris/handlers/main.yml" "roles/polaris/templates/polaris.service.j2" "roles/polaris/templates/application.properties.j2")
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ File $file exists"
    else
        echo "❌ Required file $file is missing"
        exit 1
    fi
done

echo
echo "🎉 All validation checks passed!"
echo
echo "Next steps:"
echo "1. Configure your inventory in inventory/hosts.yml with actual server IPs"
echo "2. Test connectivity: ansible -i inventory/hosts.yml polaris_servers -m ping"
echo "3. Run the playbook: ansible-playbook -i inventory/hosts.yml playbook.yml"
echo "4. Access Polaris API at http://your-server-ip:8181/api/catalog"
echo

