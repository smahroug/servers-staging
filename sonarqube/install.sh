#!/bin/bash
sh validate.sh
# SonarQube Deployment Installation Script
ansible-playbook -i inventory/hosts.yml playbook.yml
