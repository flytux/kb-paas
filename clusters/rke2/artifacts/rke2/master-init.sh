#!/bin/sh
mkdir -p /etc/rancher/rke2
cp ./rke2/config.yaml /etc/rancher/rke2/

chmod +x ./rke2/v1.26.8/install.sh
INSTALL_RKE2_ARTIFACT_PATH=/root/rke2/v1.26.8 ./rke2/v1.26.8/install.sh --write-kubeconfig-mode 644 
systemctl enable rke2-server.service --now

# Install kubectl
chmod +x ./rke2/v1.26.8/kubectl && mv ./rke2/v1.26.8/kubectl /usr/local/bin

mkdir -p $HOME/.kube && cp /etc/rancher/rke2/rke2.yaml $HOME/.kube/config
