#!/bin/bash
sh validate.sh
# Flink Deployment Installation Script
ansible-playbook -i inventory/hosts.yml playbook.yml