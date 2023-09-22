resource "local_file" "prepare-kubespray-script" {
  depends_on = [libvirt_domain.kubespray_node]
    content     = templatefile("${path.module}/artifacts/templates/run-kubespray.sh", {
                    prefix_ip = var.prefix_ip
                    nodes = var.kubespray_nodes
                   })
    filename = "${path.module}/artifacts/run-kubespray.sh"
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
  source      = "artifacts/run-kubespray.sh"
  destination = "run-kubespray.sh"
  }

  provisioner "remote-exec" {
  inline = [<<EOF
        sh run-kubespray.sh
    EOF
    ]
  }

} 

