resource "terraform_data" "copy-installer" {
  depends_on = [local_file.worker]
  for_each = var.rke2_nodes
  connection {
    host        = "${var.prefixIP}.${each.value.octetIP}"
    user        = "root"
    type        = "ssh"
    private_key = file("../kvm/.ssh-default/id_rsa.key")
    timeout     = "1m"
  }

  provisioner "file" {
    source      = "artifacts/rke2"
    destination = "/root"
  }

  provisioner "remote-exec" {
    inline = [<<EOF
      chmod +x rke2/deploy.sh
      ./rke2/deploy.sh
    EOF
    ]
  }
}
