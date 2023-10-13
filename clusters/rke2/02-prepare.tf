resource "random_string" "token" {
  length           = 108
  special          = true
  numeric          = true
  lower            = true
  upper            = true
  override_special = ":"
}

resource "tls_private_key" "generic-ssh-key" {
  algorithm = "RSA"
  rsa_bits  = 4096

  provisioner "local-exec" {
    command = <<EOF
      mkdir -p .ssh-${terraform.workspace}/
      echo "${tls_private_key.generic-ssh-key.private_key_openssh}" > .ssh-${terraform.workspace}/id_rsa.key
      echo "${tls_private_key.generic-ssh-key.public_key_openssh}" > .ssh-${terraform.workspace}/id_rsa.pub
      chmod 400 .ssh-${terraform.workspace}/id_rsa.key
      chmod 400 .ssh-${terraform.workspace}/id_rsa.key
    EOF
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
      rm -rvf .ssh-${terraform.workspace}/
    EOF
  }
}

resource "local_file" "cluster_config" {
  content     = templatefile("${path.module}/artifacts/templates/config.yaml", {
                token = random_string.token.result
                master_ip = var.master_ip
              })
  filename = "${path.module}/artifacts/rke2/config.yaml"
}

resource "local_file" "deploy" {
  content     = templatefile("${path.module}/artifacts/templates/deploy.sh", {
                token = random_string.token.result
                master_ip = var.master_ip
              })
  filename = "${path.module}/artifacts/rke2/deploy.sh"
}

resource "local_file" "master-init" {
  depends_on = [local_file.deploy]
  content     = templatefile("${path.module}/artifacts/templates/master-init.sh", {
                token = random_string.token.result
              })
  filename = "${path.module}/artifacts/rke2/master-init.sh"
}

resource "local_file" "master-member" {
  depends_on = [local_file.master-init]
  content     = templatefile("${path.module}/artifacts/templates/master-member.sh", {
                token = random_string.token.result
                master_ip = var.master_ip
              })
  filename = "${path.module}/artifacts/rke2/master-member.sh"
}

resource "local_file" "worker" {
  depends_on = [local_file.master-member]
  content     = templatefile("${path.module}/artifacts/templates/worker.sh", {
                token = random_string.token.result
                master_ip = var.master_ip
              })
  filename = "${path.module}/artifacts/rke2/worker.sh"
}

