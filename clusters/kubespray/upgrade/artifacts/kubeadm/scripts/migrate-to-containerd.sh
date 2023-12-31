#!/bin/sh

setenforce 0
sed -i --follow-symlinks 's/SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux

echo "=== install rpms  ==="
 # Install required packages
echo "10.10.10.101  repo.kw01 docker.kw01" >> /etc/hosts

echo "=== update registry ca certs ==="
cp kubeadm/certs/* /etc/pki/ca-trust/source/anchors/
update-ca-trust

#rpm -Uvh kubeadm/packages/*.rpm
rm -rf /etc/yum.repos.d/Rocky*
cat << EOF > /etc/yum.repos.d/kw01.repo
[kw01]
name=kw01
baseurl=http://repo.kw01/repo/
gpgcheck=0
enabled=1
module_hotfixes=1
EOF

rpm -Uvh --force kubeadm/packages/*.rpm

mkdir -p /etc/containerd
\cp kubeadm/packages/config.toml /etc/containerd/

mkdir -p /etc/nerdctl
cp kubeadm/kubernetes/config/nerdctl.toml /etc/nerdctl/nerdctl.toml
systemctl restart containerd

\cp kubeadm/kubernetes/bin/*ctl /usr/local/bin && chmod +x /usr/local/bin/*

\cp -rf kubeadm/cni /opt
\cp -rf kubeadm/.kube $HOME

echo "=== change container runtime annotaion of nodes  ==="
while ! kubectl get node $(hostname) -o yaml | sed "/creationTimestamp.*/d" | sed "/resourceVersion.*/d" | sed "/uid.*/d" | sed "s/unix:.*/unix:\/\/\/run\/containerd\/containerd.sock/g" | kubectl apply -f - ; do echo please waits for api-server up; sleep 5; done

echo "=== stop kubelet ==="
systemctl stop kubelet

\cp kubeadm/kubernetes/config/kubelet.service /etc/systemd/system
\cp -r kubeadm/kubernetes/config/kubelet.service.d /etc/systemd/system

cat /var/lib/kubelet/kubeadm-flags.env | sed "s/unix:.*sock/unix:\/\/\/run\/containerd\/containerd.sock/g" > kf.env; mv -f kf.env /var/lib/kubelet/kubeadm-flags.env

crictl config runtime-endpoint unix:///run/containerd/containerd.sock
crictl config image-endpoint

echo "=== start kubelet ==="
systemctl daemon-reload
systemctl enable kubelet --now
systemctl disable docker.service --now
