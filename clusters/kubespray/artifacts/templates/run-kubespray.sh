#!/bin/sh

python3 -m pip install kubeadm/python/*.whl 

tar xf kubeadm/kubespray.tgz -C kubeadm

cd kubeadm/kubespray

cp -rfp inventory/sample inventory/mycluster

declare -a IPS=(%{ for k, v in nodes } ${prefix_ip}.${v.octetIP}%{ endfor } )

CONFIG_FILE=inventory/mycluster/hosts.yaml python3 contrib/inventory_builder/inventory.py $${IPS[@]}
chmod 400 ~/.ssh/id_rsa.key

ansible-playbook -i inventory/mycluster/hosts.yaml  \
  -e kube_version=v1.26.8 -e etcd_deployment_type=kubeadm -e skip_downloads=false \
  -e local_release_dir=/root/kubeadm/kubernetes/v1.26.8 -e skip_kubeadm_images=true \
  --private-key=~/.ssh/id_rsa.key --become --become-user=root cluster.yml
