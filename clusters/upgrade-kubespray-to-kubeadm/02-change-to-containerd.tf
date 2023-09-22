resource "terraform_data" "prepare_kubeconfig" {
  provisioner "local-exec" {
    command = <<EOF
      mkdir artifacts/kubeadm/.kube
      ssh -i ../kubespray/.ssh-default/id_rsa.key -o StrictHostKeyChecking=no ${var.master_ip} -- cat /etc/kubernetes/admin.conf > artifacts/kubeadm/.kube/config
      sed -i "s/127\.0\.0\.1/${var.master_ip}/g" artifacts/kubeadm/.kube/config
    EOF
  }
}


resource "terraform_data" "master_init_containerd_upgrade" {
  depends_on = [terraform_data.prepare_kubeconfig]
  for_each =  {for key, val in var.kubeadm_nodes:
               key => val if val.role == "master-init"}
  connection {
    host        = "${var.prefix_ip}.${each.value.octetIP}"
    user        = "root"
    type        = "ssh"
    private_key = file("${path.module}/../kubespray/.ssh-default/id_rsa.key")
    timeout     = "2m"
  }

  provisioner "file" {
    source      = "artifacts/kubeadm"
    destination = "/root"
  }

  provisioner "remote-exec" {
    inline = [<<EOF
       
      setenforce 0
      sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
      
      
      echo "=== install rpms  ==="
      rpm -Uvh kubeadm/packages/*.rpm

      mkdir -p /etc/containerd
      \cp kubeadm/packages/config.toml /etc/containerd/

      mkdir -p /etc/nerdctl
      cp kubeadm/bin/nerdctl.toml /etc/nerdctl/nerdctl.toml
      systemctl restart containerd
      
      \cp kubeadm/bin/nerdctl /usr/local/bin && chmod +x /usr/local/bin/*
      nerdctl load -i kubeadm/kubeadm.tar

      \cp -rf kubeadm/cni /opt

      echo "=== change container runtime annotaion of nodes  ==="
      kubectl get node $(hostname) -o yaml | sed "s/unix:.*/unix:\/\/\/run\/containerd\/containerd.sock/g" | kubectl apply -f -
      systemctl stop kubelet
      

      \cp kubeadm/kubelet.service /etc/systemd/system
      \cp -r kubeadm/kubelet.service.d /etc/systemd/system

      cat /var/lib/kubelet/kubeadm-flags.env | sed "s/unix:.*sock/unix:\/\/\/run\/containerd\/containerd.sock/g" > kf.env; mv -f kf.env /var/lib/kubelet/kubeadm-flags.env
      # Need to setup crictl endpoint, image-endpoint

      crictl config runtime-endpoint unix:///run/containerd/containerd.sock
      crictl config image-endpoint
      
      systemctl daemon-reload
      systemctl enable kubelet --now
      systemctl disable docker.service --now

    EOF
    ]
  }
}

resource "terraform_data" "master_member_containerd_upgrade" {
  depends_on = [terraform_data.master_init_containerd_upgrade]
  for_each =  {for key, val in var.kubeadm_nodes:
               key => val if val.role == "master-member"}
  connection {
    host        = "${var.prefix_ip}.${each.value.octetIP}"
    user        = "root"
    type        = "ssh"
    private_key = file("${path.module}/../kubespray/.ssh-default/id_rsa.key")
    timeout     = "2m"
  }

  provisioner "file" {
    source      = "artifacts/kubeadm"
    destination = "/root"
  }

  provisioner "remote-exec" {
    inline = [<<EOF
       
      setenforce 0
      sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

      echo "=== install rpms  ==="
      rpm -Uvh kubeadm/packages/*.rpm

      mkdir -p /etc/containerd
      \cp kubeadm/packages/config.toml /etc/containerd/

      mkdir -p /etc/nerdctl
      cp kubeadm/bin/nerdctl.toml /etc/nerdctl/nerdctl.toml
      systemctl restart containerd

      \cp kubeadm/bin/nerdctl /usr/local/bin && chmod +x /usr/local/bin/*
      nerdctl load -i kubeadm/kubeadm.tar

      \cp -rf kubeadm/cni /opt

      echo "=== change container runtime annotaion of nodes  ==="
      kubectl get node $(hostname) -o yaml | sed "s/unix:.*/unix:\/\/\/run\/containerd\/containerd.sock/g" | kubectl apply -f -
      systemctl stop kubelet
      

      \cp kubeadm/kubelet.service /etc/systemd/system
      \cp -r kubeadm/kubelet.service.d /etc/systemd/system

      cat /var/lib/kubelet/kubeadm-flags.env | sed "s/unix:.*sock/unix:\/\/\/run\/containerd\/containerd.sock/g" > kf.env; mv -f kf.env /var/lib/kubelet/kubeadm-flags.env
      # Need to setup crictl endpoint, image-endpoint

      crictl config runtime-endpoint unix:///run/containerd/containerd.sock
      crictl config image-endpoint
      
      systemctl daemon-reload
      systemctl enable kubelet --now
      systemctl disable docker.service --now

    EOF
    ]
  }
}

resource "terraform_data" "worker_containerd_upgrade" {
  depends_on = [terraform_data.master_init_containerd_upgrade]  
  for_each =  {for key, val in var.kubeadm_nodes:
               key => val if val.role == "worker"}
  connection {
    host        = "${var.prefix_ip}.${each.value.octetIP}"
    user        = "root"
    type        = "ssh"
    private_key = file("${path.module}/../kubespray/.ssh-default/id_rsa.key")
    timeout     = "2m"
  }

  provisioner "file" {
    source      = "artifacts/kubeadm"
    destination = "/root"
  }

  provisioner "remote-exec" {
    inline = [<<EOF

      cp -R kubeadm/.kube $HOME

      setenforce 0
      sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

      echo "=== install rpms  ==="
      rpm -Uvh kubeadm/packages/*.rpm

      mkdir -p /etc/containerd
      \cp kubeadm/packages/config.toml /etc/containerd/

      mkdir -p /etc/nerdctl
      cp kubeadm/bin/nerdctl.toml /etc/nerdctl/nerdctl.toml
      systemctl restart containerd

      \cp kubeadm/bin/nerdctl /usr/local/bin && chmod +x /usr/local/bin/*
      nerdctl load -i kubeadm/kubeadm.tar

      \cp -rf kubeadm/cni /opt

      \cp kubeadm/bin/kubectl /usr/local/bin
      echo "=== change container runtime annotaion of nodes  ==="
      \cp kubeadm/bin/kubectl /usr/local/bin && chmod +x /usr/local/bin/*

      kubectl get node $(hostname) -o yaml | sed "s/unix:.*/unix:\/\/\/run\/containerd\/containerd.sock/g" | kubectl apply -f -
      systemctl stop kubelet
      
      \cp kubeadm/kubelet.service /etc/systemd/system
      \cp -r kubeadm/kubelet.service.d /etc/systemd/system

      cat /var/lib/kubelet/kubeadm-flags.env | sed "s/unix:.*sock/unix:\/\/\/run\/containerd\/containerd.sock/g" > kf.env; mv -f kf.env /var/lib/kubelet/kubeadm-flags.env
      # Need to setup crictl endpoint, image-endpoint

      crictl config runtime-endpoint unix:///run/containerd/containerd.sock
      crictl config image-endpoint

      
      systemctl daemon-reload
      systemctl enable kubelet --now
      systemctl disable docker.service --now

    EOF
    ]
  }
}
