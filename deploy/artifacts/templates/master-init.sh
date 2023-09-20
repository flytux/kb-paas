# 01 init cluster 
modprobe br_netfilter
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward


#sudo kubeadm init --cri-socket /run/containerd/containerd.sock --pod-network-cidr=192.168.0.0/16 --upload-certs --control-plane-endpoint=${master_ip}:6443 | \
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --upload-certs --control-plane-endpoint=${master_ip}:6443 | \
sed -e '/kubeadm join/,/--certificate-key/!d' | head -n 3 > join_cmd
# 02 copy kubeconfig
mkdir -p $HOME/.kube
sudo cp -ru /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 03 install cni
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/tigera-operator.yaml
sleep 5 #wait for the deployment to start the required pods
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/custom-resources.yaml
sleep 5 #wait for the deployment to start the required pods
