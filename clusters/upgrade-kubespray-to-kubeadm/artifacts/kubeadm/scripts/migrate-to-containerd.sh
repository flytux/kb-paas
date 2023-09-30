#!/bin/sh

setenforce 0
sed -i --follow-symlinks 's/SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux

echo "=== install rpms  ==="
rpm -Uvh kubeadm/packages/*.rpm

mkdir -p /etc/containerd
\cp kubeadm/packages/config.toml /etc/containerd/

echo "=== update registry ca certs ==="
cp kubeadm/certs/* /etc/pki/ca-trust/source/anchors/
update-ca-trust
echo "10.10.10.101 docker.kw01" >> /etc/hosts

mkdir -p /etc/nerdctl
cp kubeadm/kubernetes/config/nerdctl.toml /etc/nerdctl/nerdctl.toml
systemctl restart containerd

\cp kubeadm/kubernetes/bin/*ctl /usr/local/bin && chmod +x /usr/local/bin/*
nerdctl load -i kubeadm/images/kubeadm.tar

\cp -rf kubeadm/cni /opt

echo "=== change container runtime annotaion of nodes  ==="
kubectl get node $(hostname) -o yaml | sed "/creationTimestamp.*/d" | sed "/resourceVersion.*/d" | sed "/uid.*/d" | sed "s/unix:.*/unix:\/\/\/run\/containerd\/containerd.sock/g" | kubectl apply -f -
systemctl stop kubelet

\cp kubeadm/kubernetes/config/kubelet.service /etc/systemd/system
\cp -r kubeadm/kubernetes/config/kubelet.service.d /etc/systemd/system

cat /var/lib/kubelet/kubeadm-flags.env | sed "s/unix:.*sock/unix:\/\/\/run\/containerd\/containerd.sock/g" > kf.env; mv -f kf.env /var/lib/kubelet/kubeadm-flags.env

crictl config runtime-endpoint unix:///run/containerd/containerd.sock
crictl config image-endpoint

systemctl daemon-reload
systemctl enable kubelet --now
systemctl disable docker.service --now
