resource "terraform_data" "copy_upgrade_containerd" {
  for_each = var.kubeadm_nodes
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

      systemctl stop kubelet
      systemctl disable docker.service --now

      mkdir -p /etc/containerd
      cp kubeadm/packages/config.toml /etc/containerd/
      mkdir -p /etc/nerdctl
      cp kubeadm/bin/nerdctl.toml /etc/nerdctl/nerdctl.toml
      systemctl restart containerd

      nerdctl load -i kubeadm/kubeadm.tar

      cp kubeadm/bin/* /usr/local/bin
      chmod +x /usr/local/bin/*
      cp -R kubeadm/cni /opt

      cp kubeadm/kubelet.service /etc/systemd/system
      mv -f kubeadm/kubelet.service.d /etc/systemd/system

      cat /var/lib/kubelet/kubeadm-flags.env | sed "s/unix:.*sock/unix:\/\/\/run\/containerd\/containerd.sock/g" > kf.env; mv -f kf.env /var/lib/kubelet/kubeadm-flags.env
      echo "=== change container runtime annotaion of nodes  ==="
      kubectl get nodes -o yaml | sed "s/unix:.*/unix:\/\/\/run\/containerd\/containerd.sock/g" | kubectl apply -f -

      systemctl daemon-reload
      systemctl enable kubelet --now

    EOF
    ]
  }
}

