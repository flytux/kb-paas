#!/bin/sh

# Disble SELINUX 
setenforce 0
sed -i --follow-symlinks 's/SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux

# add yum repo
echo "${master_ip} ${yum_domain}" >> /etc/hosts

# Install required packages
yum install -y kubeadm/packages/*.rpm

# Install containerd
mkdir -p /etc/containerd
cp kubeadm/packages/config.toml /etc/containerd/
mkdir -p /etc/nerdctl
cp kubeadm/kubernetes/config/nerdctl.toml /etc/nerdctl/nerdctl.toml

systemctl restart containerd

# Copy kubeadm and network binaries
cp kubeadm/kubernetes/bin/* /usr/local/bin
chmod +x /usr/local/bin/*
cp -R kubeadm/cni /opt

# Load kubeadm container images
nerdctl load -i kubeadm/images/kubeadm.tar

# Configure and start kubelet
cp kubeadm/kubernetes/config/kubelet.service /etc/systemd/system
mv kubeadm/kubernetes/config/kubelet.service.d /etc/systemd/system

systemctl daemon-reload
systemctl enable kubelet --now
