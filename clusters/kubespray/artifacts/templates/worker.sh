# 01 init node
modprobe br_netfilter
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward

chmod 400 $HOME/.ssh/id_rsa.key

until [ $(ssh -i /root/.ssh/id_rsa.key -o StrictHostKeyChecking=no ${master_ip} -- cat join_cmd | wc -l) != 0 ];
do
        echo "Wait Master Node Init.."
	sleep 10
done
        ssh -i $HOME/.ssh/id_rsa.key -o StrictHostKeyChecking=no ${master_ip} -- kubeadm token create --print-join-command | sh -

mkdir -p $HOME/.kube
ssh -i $HOME/.ssh/id_rsa.key -o StrictHostKeyChecking=no ${master_ip} -- cat /etc/kubernetes/admin.conf > $HOME/.kube/config
sed -i "s/127\.0\.0\.1/{master_ip}/g" $HOME/.kube/config
