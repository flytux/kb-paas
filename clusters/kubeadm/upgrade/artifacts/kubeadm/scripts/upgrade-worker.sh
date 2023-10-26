#!/bin/sh
PATH=$PATH:/usr/local/bin

NEW_VERSION=v1.27.6
MASTER_IP=100.100.100.101
HOST_IP=$(hostname -I | awk '{print $1}')
OLD_VERSION=$(/usr/local/bin/kubeadm version | grep -oE 'v([1-9]|\.)+')

mkdir -p $HOME/.kube
ssh -i $HOME/.ssh/id_rsa.key -o StrictHostKeyChecking=no $MASTER_IP -- cat /etc/kubernetes/admin.conf > $HOME/.kube/config
sed -i "s/127\.0\.0\.1/$MASTER_IP/g" $HOME/.kube/config

echo "=== check kubeadm plan ==="
mv /usr/local/bin/kubeadm kubeadm-$OLD_VERSION
cp kubeadm/kubernetes/$NEW_VERSION/kubeadm /usr/local/bin/kubeadm && chmod +x /usr/local/bin/kubeadm

echo "=== upgrade node ==="
kubeadm upgrade node 

echo "=== drain node ==="
kubectl drain $(hostname) --ignore-daemonsets
echo "=== stop kubelet.service ==="
systemctl stop kubelet.service

echo "=== copy new version kubelet and restart"
cp kubeadm/kubernetes/$NEW_VERSION/kubelet /usr/local/bin/kubelet && chmod +x /usr/local/bin/kubelet

echo "=== restart kubelet.service ==="
systemctl daemon-reload
systemctl restart kubelet.service

echo "=== uncordon node ==="
kubectl uncordon $(hostname)
