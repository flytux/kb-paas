#!/bin/bash
HOSTNAME=$(hostname)
if [[ "$HOSTNAME" =~ kw-master-1 ]]
then
   echo "=== Staring Master Init node ==="
   chmod +x ./rke2/master-init.sh
   ./rke2/master-init.sh
elif [[ "$HOSTNAME" =~ kw-master.* ]]
then
   while ! curl -k https://${master_ip}:9345 > /dev/null 2>&1; do echo wait for master node api-server up; sleep 5; done
   echo "=== Staring Master Member node ==="
   chmod +x ./rke2/master-member.sh
   ./rke2/master-member.sh
else
   while ! curl -k https://${master_ip}:9345 > /dev/null 2>&1; do echo wait for master node api-server up; sleep 5; done
   echo "=== Staring Worker node ==="
   chmod +x ./rke2/worker.sh
   ./rke2/worker.sh
fi
