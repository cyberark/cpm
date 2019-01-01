#!/bin/bash
ansible-inventory -i inventory/ec2.py --list tag_kitchen_type_windows --export -y > ./inventory/hosts
echo "Ansible hosts updated successfully"