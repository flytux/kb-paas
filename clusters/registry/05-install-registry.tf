resource "local_file" "create_script" {
  depends_on = [terraform_data.init_master]
    content     = templatefile("${path.module}/${var.kubeadm_home}/templates/install-registry.sh", {
		    registry_ip = var.registry_ip,
		    registry_domain = var.registry_domain
		   })
    filename = "${path.module}/${var.kubeadm_home}/scripts/install-registry.sh"
}

resource "terraform_data" "install_registry" {
  depends_on = [local_file.create_script]
  for_each =  {for key, val in var.kubeadm_nodes:
               key => val if val.role == "master-init"}

  connection {
    host        = "${var.prefix_ip}.${each.value.octetIP}"
    user        = "root"
    type        = "ssh"
    private_key = "${tls_private_key.generic-ssh-key.private_key_openssh}"
    timeout     = "2m"
  }

  provisioner "local-exec" {
    command = <<EOF
      openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout artifacts/kubeadm/certs/registry.key -out artifacts/kubeadm/certs/registry.crt \
      -subj "/CN=*.kw01" -addext "subjectAltName=DNS:docker.kw01,DNS:repo.kw01,IP:${var.master_ip}"
    EOF
  }

  provisioner "file" {
    source      = "${var.kubeadm_home}/scripts/install-registry.sh"
    destination = "/root/kubeadm/scripts/install-registry.sh"
  }

  provisioner "file" {
    source      = "${var.kubeadm_home}/certs"
    destination = "/root/kubeadm"
  }

  provisioner "remote-exec" {
    inline = [<<EOT
    
      sh kubeadm/scripts/install-registry.sh

    EOT
    ]
  }
}
