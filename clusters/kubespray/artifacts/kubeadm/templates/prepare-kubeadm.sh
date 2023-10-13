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
#rm -rf /etc/yum.repos.d/Rocky*
#cat << EOF > /etc/yum.repos.d/kw01.repo
#[kw01]
#name=kw01
#baseurl=http://${yum_domain}/repo/
#gpgcheck=0
#enabled=1
#module_hotfixes=1
#EOF

#rpm -Uvh --force kubeadm/packages/*.rpm
yum localinstall -y kubeadm/packages/containerd.io-1.6.24-3.1.el8.x86_64.rpm
yum localinstall -y kubeadm/packages/conntrack-tools-1.4.4-11.el8.x86_64.rpm
yum localinstall -y kubeadm/packages/socat-1.7.4.1-1.el8.x86_64.rpm
yum localinstall -y kubeadm/packages/iptables-1.8.4-24.el8_8.2.x86_64.rpm
yum localinstall -y kubeadm/packages/iptables-ebtables-1.8.4-24.el8_8.2.x86_64.rpm
yum localinstall -y kubeadm/packages/nss-3.90.0-3.el8_8.x86_64.rpm
yum localinstall -y kubeadm/packages/ipset-7.1-1.el8.x86_64.rpm
yum localinstall -y kubeadm/packages/bash-completion-2.7-5.el8.noarch.rpm
yum localinstall -y kubeadm/packages/docker*.rpm

systemctl enable docker --now

docker load -i kubeadm/images/local-images.tar

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

#nerdctl load -i kubeadm/images/local-images.tar
# Configure and start kubelet
cp kubeadm/kubernetes/config/kubelet.service /etc/systemd/system
mv kubeadm/kubernetes/config/kubelet.service.d /etc/systemd/system

systemctl daemon-reload
systemctl enable kubelet --now
