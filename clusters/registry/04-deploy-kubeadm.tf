resource "local_file" "prepare_kubeadm" {
    content     = templatefile("${path.module}/${var.kubeadm_home}/templates/prepare-kubeadm.sh", {
                    master_ip = var.master_ip,
                    minio_domain = var.minio_domain
                   })
    filename = "${path.module}/${var.kubeadm_home}/scripts/prepare-kubeadm.sh"
}

resource "local_file" "master_init" {
  depends_on = [local_file.prepare_kubeadm]
    content     = templatefile("${path.module}/${var.kubeadm_home}/templates/master-init.sh", {
                    master_ip = var.master_ip
                   })
    filename = "${path.module}/${var.kubeadm_home}/scripts/master-init.sh"
}

resource "local_file" "master_member" {
  depends_on = [local_file.master_init]
    content     = templatefile("${path.module}/${var.kubeadm_home}/templates/master-member.sh", {
		    master_ip = var.master_ip
		   })
    filename = "${path.module}/${var.kubeadm_home}/scripts/master-member.sh"
}

resource "local_file" "worker" {
  depends_on = [local_file.master_member]
    content     = templatefile("${path.module}/${var.kubeadm_home}/templates/worker.sh", {
		    master_ip = var.master_ip
		   })
    filename = "${path.module}/${var.kubeadm_home}/scripts/worker.sh"
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
    source      = "${var.kubeadm_home}"
    destination = "/root"
  }

  provisioner "file" {
    source      = ".ssh-default/id_rsa.key"
    destination = "/root/.ssh/id_rsa.key"
  }

  provisioner "remote-exec" {
    inline = [<<EOF
       
      chmod +x kubeadm/scripts/prepare-kubeadm.sh
      kubeadm/scripts/prepare-kubeadm.sh

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
           chmod +x kubeadm/scripts/master-init.sh
           kubeadm/scripts/master-init.sh
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
           chmod +x kubeadm/scripts/master-member.sh
           kubeadm/scripts/master-member.sh
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
           chmod +x kubeadm/scripts/worker.sh
           kubeadm/scripts/worker.sh
    EOF
    ]
  }
}
