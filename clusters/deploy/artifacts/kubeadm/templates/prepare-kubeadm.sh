#!/bin/sh

# Disble SELINUX 
setenforce 0
sed -i --follow-symlinks 's/SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux

# Install required packages
echo "${yum_ip}  ${yum_domain} ${registry_domain}" >> /etc/hosts

echo "=== update registry ca certs ==="
cp kubeadm/certs/* /etc/pki/ca-trust/source/anchors/
update-ca-trust

#rpm -Uvh kubeadm/packages/*.rpm
rm -rf /etc/yum.repos.d/Rocky*
cat << EOF > /etc/yum.repos.d/kw01.repo
[kw01]
name=kw01
baseurl=http://${yum_domain}/repo/
gpgcheck=0
enabled=1
module_hotfixes=1
EOF

#yum install -y containerd.io socat conntrack iproute-tc iptables-ebtables iptables
rpm -Uvh --force kubeadm/packages/*.rpm

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
#nerdctl load -i kubeadm/images/kubeadm.tar

# Configure and start kubelet
cp kubeadm/kubernetes/config/kubelet.service /etc/systemd/system
mv kubeadm/kubernetes/config/kubelet.service.d /etc/systemd/system

systemctl daemon-reload
systemctl enable kubelet --now
