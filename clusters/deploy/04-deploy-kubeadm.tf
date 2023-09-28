resource "local_file" "master_init" {
    content     = templatefile("${path.module}/artifacts/templates/master-init.sh", {
                    master_ip = var.master_ip
                   })
    filename = "${path.module}/artifacts/kubeadm/master-init.sh"
}

resource "local_file" "master_member" {
  depends_on = [local_file.master_init]
    content     = templatefile("${path.module}/artifacts/templates/master-member.sh", {
		    master_ip = var.master_ip
		   })
    filename = "${path.module}/artifacts/kubeadm/master-member.sh"
}

resource "local_file" "worker" {
  depends_on = [local_file.master_member]
    content     = templatefile("${path.module}/artifacts/templates/worker.sh", {
		    master_ip = var.master_ip
		   })
    filename = "${path.module}/artifacts/kubeadm/worker.sh"
}

resource "terraform_data" "copy_installer" {
  depends_on = [local_file.worker]
  for_each = var.kubeadm_nodes
  connection {
    host        = "${var.prefix_ip}.${each.value.octetIP}"
    user        = "root"
    type        = "ssh"
    private_key = "${tls_private_key.generic-ssh-key.private_key_openssh}"
    timeout     = "2m"
  }

  provisioner "file" {
    source      = "artifacts/kubeadm"
    destination = "/root"
  }

  provisioner "file" {
    source      = ".ssh-default/id_rsa.key"
    destination = "/root/.ssh/id_rsa.key"
  }

  provisioner "remote-exec" {
    inline = [<<EOF
       
      # Disble SELINUX 
      setenforce 0
      sed -i --follow-symlinks 's/SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux

      # Install required packages
      rpm -Uvh kubeadm/packages/*.rpm

      # Install containerd
      mkdir -p /etc/containerd
      cp kubeadm/packages/config.toml /etc/containerd/

      # Update registry ca-certs, dns
      cp kubeadm/certs/* /etc/pki/ca-trust/source/anchors/
      update-ca-trust

      echo "10.10.10.101 docker.kw01" >> /etc/hosts

      mkdir -p /etc/nerdctl
      cp kubeadm/kubernetes/config/nerdctl.toml /etc/nerdctl/nerdctl.toml

      systemctl restart containerd

      # Copy kubeadm and network binaries
      cp kubeadm/kubernetes/bin/* /usr/local/bin
      chmod +x /usr/local/bin/*
      cp -R kubeadm/cni /opt

      # Load kubeadm container images
      nerdctl load -i kubeadm/images/kubeadm.tar

      # Configure and start kubelet
      cp kubeadm/kubernetes/config/kubelet.service /etc/systemd/system
      mv kubeadm/kubernetes/config/kubelet.service.d /etc/systemd/system

      systemctl daemon-reload
      systemctl enable kubelet --now

    EOF
    ]
  }
}

resource "terraform_data" "init_master" {
  depends_on = [terraform_data.copy_installer]

  for_each =  {for key, val in var.kubeadm_nodes:
               key => val if val.role == "master-init"}

  connection {
    type        = "ssh"
    user        = "root"
    private_key = "${tls_private_key.generic-ssh-key.private_key_openssh}"
    host        = "${var.prefix_ip}.${each.value.octetIP}"
  }

  provisioner "remote-exec" {
    inline = [<<EOF
           
           # Start kubeadm init
           chmod +x ./kubeadm/master-init.sh
           ./kubeadm/master-init.sh
    EOF
    ]
  }
}


resource "terraform_data" "add_master" {
  depends_on = [terraform_data.init_master]

  for_each =  {for key, val in var.kubeadm_nodes:
               key => val if val.role == "master-member"}

  connection {
    type        = "ssh"
    user        = "root"
    private_key = "${tls_private_key.generic-ssh-key.private_key_openssh}"
    host        = "${var.prefix_ip}.${each.value.octetIP}"
  }

  provisioner "remote-exec" {
  inline = [<<EOF

           # Start kubeadm init
           chmod +x ./kubeadm/master-member.sh
           ./kubeadm/master-member.sh
    EOF
    ]
  }
}

resource "terraform_data" "add_worker" {
  depends_on = [terraform_data.init_master]

  for_each =  {for key, val in var.kubeadm_nodes:
               key => val if val.role == "worker"}

  connection {
    type        = "ssh"
    user        = "root"
    private_key = "${tls_private_key.generic-ssh-key.private_key_openssh}"
    host        = "${var.prefix_ip}.${each.value.octetIP}"
  }

  provisioner "remote-exec" {
    inline = [<<EOF

           # Start kubeadm join
           chmod +x ./kubeadm/worker.sh
           ./kubeadm/worker.sh
    EOF
    ]
  }
}
