#!/bin/sh
PATH=$PATH:/usr/local/bin

NEW_VERSION=v1.27.6
MASTER_IP=101.101.101.101
HOST_IP=$(hostname -I | awk '{print $1}')
OLD_VERSION=$(/usr/local/bin/kubeadm version | grep -oE 'v([1-9]|\.)+')

echo "=== check kubeadm plan ==="
mv /usr/local/bin/kubeadm kubeadm-$OLD_VERSION
cp kubeadm/kubernetes/$NEW_VERSION/kubeadm /usr/local/bin/kubeadm && chmod +x /usr/local/bin/kubeadm

crictl config image-endpoint

kubeadm upgrade plan

if [ "$HOST_IP" = "$MASTER_IP" ]
  then
    echo "=== upgrade master init node ==="
    kubeadm upgrade apply $NEW_VERSION -y
  else
    echo "=== upgrade master member node ==="
    kubeadm upgrade node 
fi

echo "=== stop kubelet.service ==="
systemctl stop kubelet.service

echo "=== copy new version kubelet and restart"
cp kubeadm/kubernetes/$NEW_VERSION/kubelet /usr/local/bin/kubelet && chmod +x /usr/local/bin/kubelet

echo "=== restart kubelet.service ==="
systemctl daemon-reload
systemctl restart kubelet.service
