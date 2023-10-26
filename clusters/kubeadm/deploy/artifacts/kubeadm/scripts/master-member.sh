# 01 init cluster
modprobe br_netfilter
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
chmod 400 $HOME/.ssh/id_rsa.key

dnf install -y socat conntrack

until [ $(ssh -i /root/.ssh/id_rsa.key -o StrictHostKeyChecking=no 100.100.100.101 -- cat join_cmd | wc -l) != 0 ];
do
        echo "Wait Master Node Init.."
	sleep 10
done
        ssh -i /root/.ssh/id_rsa.key -o StrictHostKeyChecking=no 100.100.100.101 -- cat join_cmd | sh -
