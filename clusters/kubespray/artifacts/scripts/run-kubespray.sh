#!/bin/sh
yum localinstall -y kubeadm/packages/python39-3.9.16-1.module+el8.8.0+1328+24532da6.1.x86_64.rpm

python3 -m pip install kubeadm/python/*.whl 

cd kubeadm/kubespray

cp -rfp inventory/sample inventory/mycluster

declare -a IPS=( 101.101.101.101 101.101.101.102 101.101.101.201 )

CONFIG_FILE=inventory/mycluster/hosts.yaml python3 contrib/inventory_builder/inventory.py ${IPS[@]}
chmod 400 ~/.ssh/id_rsa.key

ansible-playbook -i inventory/mycluster/hosts.yaml  \
  -e kube_version=v1.26.8 -e etcd_deployment_type=kubeadm -e skip_downloads=true \
  -e local_release_dir=/root/kubeadm/kubernetes/v1.26.8 -e skip_kubeadm_images=true \
  -e container_manager=docker \
  --private-key=~/.ssh/id_rsa.key --become --become-user=root cluster.yml

 while ! kubectl create -f $HOME/kubeadm/cni/calico.yaml ; do echo please waits for api-server up; sleep 5; done
