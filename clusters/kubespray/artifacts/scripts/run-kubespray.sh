#!/bin/sh

dnf install python39 git -y
python3 -m pip install --user ansible-core==2.14.5

git clone https://github.com/kubernetes-sigs/kubespray.git

cd kubespray
pip3 install -r requirements.txt
cp -rfp inventory/sample inventory/mycluster


declare -a IPS=( 101.101.101.101 101.101.101.102 101.101.101.201 )

CONFIG_FILE=inventory/mycluster/hosts.yaml python3 contrib/inventory_builder/inventory.py ${IPS[@]}
chmod 400 ~/.ssh/id_rsa.key
ansible-playbook -i inventory/mycluster/hosts.yaml  -e kube_version=v1.26.8 -e container_manager=docker --private-key=~/.ssh/id_rsa.key --become --become-user=root cluster.yml

