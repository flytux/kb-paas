resource "terraform_data" "upgrade_master_init" {

  for_each =  {for key, val in var.kubeadm_nodes:
               key => val if val.role == "master-init"}

  provisioner "local-exec" {
    command = <<EOF
      echo "Create upgrade-master.sh"
      sed -i "s/NEW_VERSION=.*/NEW_VERSION=${var.new_version}/" artifacts/kubeadm/scripts/upgrade-master.sh
      sed -i "s/MASTER_IP=.*/MASTER_IP=${var.master_ip}/" artifacts/kubeadm/scripts/upgrade-master.sh
      cat artifacts/kubeadm/scripts/upgrade-master.sh | grep NEW_VERSION
    EOF
  }

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("${path.module}/../deploy/.ssh-default/id_rsa.key")
    host        = "${var.prefixIP}.${each.value.octetIP}"
  }

  provisioner "file" {
  source      = "artifacts/kubeadm/scripts/upgrade-master.sh"
  destination = "/root/kubeadm/scripts/upgrade-master.sh"
  }

  provisioner "file" {
  source      = "artifacts/kubeadm/kubernetes/${var.new_version}"
  destination = "/root/kubeadm"
  }

  provisioner "remote-exec" {
  inline = [<<EOF
      chmod +x ./kubeadm/scripts/upgrade-master.sh
      sudo ./kubeadm/scripts/upgrade-master.sh
    EOF
    ]
  }

} 

resource "terraform_data" "upgrade_master_member" {
  depends_on = [terraform_data.upgrade_master_init]

  for_each =  {for key, val in var.kubeadm_nodes:
               key => val if val.role == "master-member"}

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("${path.module}/../deploy/.ssh-default/id_rsa.key")
    host        = "${var.prefixIP}.${each.value.octetIP}"
  }

  provisioner "file" {
  source      = "artifacts/kubeadm/scripts/upgrade-master.sh"
  destination = "/root/kubeadm/scripts/upgrade-master.sh"
  }

  provisioner "file" {
  source      = "artifacts/kubeadm/kubernetes/${var.new_version}"
  destination = "/root/kubeadm"
  }

  provisioner "remote-exec" {
  inline = [<<EOF
      chmod +x ./kubeadm/scripts/upgrade-master.sh
      sudo ./kubeadm/scripts/upgrade-master.sh
    EOF
    ]
  }

} 
resource "terraform_data" "upgrade-worker" {
  depends_on = [terraform_data.upgrade_master_member]

  for_each =  {for key, val in var.kubeadm_nodes:
               key => val if val.role == "worker"}

  provisioner "local-exec" {
    command = <<EOF
      echo "Create upgrade-worker.sh"
      sed -i "s/NEW_VERSION=.*/NEW_VERSION=${var.new_version}/" artifacts/kubeadm/scripts/upgrade-worker.sh
      sed -i "s/MASTER_IP=.*/MASTER_IP=${var.master_ip}/" artifacts/kubeadm/scripts/upgrade-worker.sh
      cat artifacts/kubeadm/scripts/upgrade-worker.sh | grep NEW_VERSION
    EOF
  }

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("${path.module}/../deploy/.ssh-default/id_rsa.key")
    host        = "${var.prefixIP}.${each.value.octetIP}"
  }

  provisioner "file" {
  source      = "artifacts/kubeadm/scripts/upgrade-worker.sh"
  destination = "/root/kubeadm/scripts/upgrade-worker.sh"
  }

  provisioner "file" {
  source      = "artifacts/kubeadm/kubernetes/${var.new_version}"
  destination = "/root/kubeadm"
  }

  provisioner "remote-exec" {
  inline = [<<EOF
      chmod +x ./kubeadm/scripts/upgrade-worker.sh
      sudo ./kubeadm/scripts/upgrade-worker.sh
    EOF
    ]
  }

} 
