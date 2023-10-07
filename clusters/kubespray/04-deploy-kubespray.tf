resource "local_file" "prepare_kubeadm" {
  depends_on = [libvirt_domain.kubespray_node]
    content     = templatefile("${path.module}/${var.kubeadm_home}/templates/prepare-kubeadm.sh", {
                    yum_ip = var.yum_ip,
                    yum_domain = var.yum_domain,
                    registry_domain = var.registry_domain
                   })
    filename = "${path.module}/${var.kubeadm_home}/scripts/prepare-kubeadm.sh"
}

resource "terraform_data" "copy_installer" {
  depends_on = [local_file.prepare_kubeadm]
  for_each = var.kubespray_nodes
  connection {
    host        = "${var.prefix_ip}.${each.value.octetIP}"
    user        = "root"
    type        = "ssh"
    private_key = "${tls_private_key.generic-ssh-key.private_key_openssh}"
    timeout     = "2m"
  }

  provisioner "local-exec" {
    command = <<EOF
    cp ../registry/artifacts/kubeadm/certs/* ${var.kubeadm_home}/certs/
    EOF
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

resource "local_file" "prepare-kubespray-script" {
  depends_on = [terraform_data.copy_installer]
    content     = templatefile("${path.module}/artifacts/templates/run-kubespray.sh", {
                    prefix_ip = var.prefix_ip
                    nodes = var.kubespray_nodes
                   })
    filename = "${path.module}/artifacts/scripts/run-kubespray.sh"
}

resource "terraform_data" "run_kubespray" {
  depends_on = [local_file.prepare-kubespray-script]

  connection {
    type        = "ssh"
    user        = "root"
    private_key = "${tls_private_key.generic-ssh-key.private_key_openssh}"
    host        = "${var.master_ip}"
  }

  provisioner "file" {
  source      = ".ssh-default/id_rsa.key"
  destination = "/root/.ssh/id_rsa.key"
  }

  provisioner "file" {
  source      = "artifacts/scripts/run-kubespray.sh"
  destination = "run-kubespray.sh"
  }

  provisioner "remote-exec" {
  inline = [<<EOF
        sh run-kubespray.sh
    EOF
    ]
  }
} 

