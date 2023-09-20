# Kubeadm Libvirt cluster deploy & upgrade with Terraform

- Airgapped install
- VM OS agnostic
- Kubernetes version upgrade

---
### Current Status

- install VMS
- install containerd
- install kubeadm, kubelet and related bianries
- install container images
- copy script to init, join and token

---
## Upgrades

For Minor Upgardes -> Review the requiremets and related artifacts to upgrade
- kubeadm upgrade plan v1.26.7 > v1.26.8
- wget https://dl.k8s.io/v1.26.8/kubernetes-server-linux-amd64.tar.gz

### 1st control plane upgrade
- mv /usr/local/bin/kubeadm /usr/local/bin/kubeadm-v1.26.7
- cp kubeadm /usr/local/bin
- kubeadm upgrade apply v1.26.8
- systemctl stop kubelet
- mv /usr/local/bin/kubelet /usr/local/bin/kubelet-v1.26.7
- cp kubelet /usr/local/bin/kubelet
- sudo systemctl daemon-reload
- systemctl restart kubelet

### 2nd and more control plane upgrade
- mv /usr/local/bin/kubeadm /usr/local/bin/kubeadm-v1.26.7
- cp kubeadm /usr/local/bin
- kubeadm upgrade node v1.26.8
- systemctl stop kubelet
- mv /usr/local/bin/kubelet /usr/local/bin/kubelet-v1.26.7
- cp kubelet /usr/local/bin/kubelet
- sudo systemctl daemon-reload
- systemctl restart kubelet

### worker node upgrade
- mv /usr/local/bin/kubeadm /usr/local/bin/kubeadm-v1.26.7
- cp kubeadm /usr/local/bin
- kubeadm upgrade node v1.26.8
- kubectl drain $NODE_NAME --ignore-daemonsets
- systemctl stop kubelet
- mv /usr/local/bin/kubelet /usr/local/bin/kubelet-v1.26.7
- cp kubelet /usr/local/bin/kubelet
- sudo systemctl daemon-reload
- systemctl restart kubelet
- kubectl uncordon $NODE_NAME



# Update 23/09/12
- install package via dpkg errors with package db lock => changed to cloud-init package add
