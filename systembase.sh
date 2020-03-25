#!/bin/bash

inventory='/opt/jenkins/inventories/fse/fse-internal'

#limit_hostgroup=$1
#vcenter_password=$2

#below command cab be executed with "--force" at the end 
ansible-galaxy install -r roles/requirements.yml

ansible-playbook playbooks/systembase.yml -i $inventory -f 5 --private-key /opt/jenkins/secrets/ansible.key  --vault-password-file /opt/jenkins/secrets/vault.txt -e limit_hostgroup=$1 -e use_vcenter=true -e vcenter_username=administrator@vsphere.local -e newinstall=true -e vcenter_password=$vcenter_password ; done
