#!/bin/sh
mkdir -p /etc/rancher/rke2
sed -i '1iserver: https://17.10.10.11:9345' rke2/config.yaml
cp ./rke2/config.yaml /etc/rancher/rke2/

chmod +x ./rke2/v1.26.8/install.sh
INSTALL_RKE2_ARTIFACT_PATH=/root/rke2/v1.26.8 INSTALL_RKE2_TYPE=agent ./rke2/v1.26.8/install.sh
systemctl enable rke2-agent.service --now
