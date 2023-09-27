resource "terraform_data" "prepare_kubeconfig" {
  provisioner "local-exec" {
    command = <<EOF
      mkdir artifacts/kubeadm/.kube
      ssh -i ../kubespray/.ssh-default/id_rsa.key -o StrictHostKeyChecking=no ${var.master_ip} -- cat /etc/kubernetes/admin.conf > artifacts/kubeadm/.kube/config
      sed -i "s/127\.0\.0\.1/${var.master_ip}/g" artifacts/kubeadm/.kube/config
    EOF
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
      rm -rvf artifacts/kubeadm/.kube
    EOF
  }
}


resource "local_file" "prepare_migrate_to_containerd" {
  depends_on = [terraform_data.prepare_kubeconfig]
    content     = templatefile("${path.module}/artifacts/templates/migrate-to-containerd.sh", {
                    master_ip = var.master_ip
                  })
    filename = "${path.module}/artifacts/kubeadm/scripts/migrate-to-containerd.sh"
}


resource "terraform_data" "master_init_containerd_upgrade" {
  depends_on = [local_file.prepare_migrate_to_containerd]
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

      sh kubeadm/scripts/migrate-to-containerd.sh
       
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

      sh kubeadm/scripts/migrate-to-containerd.sh

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

      sh kubeadm/scripts/migrate-to-containerd.sh

    EOF
    ]
  }
}
