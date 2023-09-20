resource "terraform_data" "upgrade_master_init" {

  for_each =  {for key, val in var.kubeadm_nodes:
               key => val if val.role == "master-init"}

  provisioner "local-exec" {
    command = <<EOF
      echo "Create upgrade-master.sh"
      sed -i "s/NEW_VERSION=.*/NEW_VERSION=${var.new_version}/" artifacts/kubeadm/upgrade-master.sh
      sed -i "s/MASTER_IP=.*/MASTER_IP=${var.master_ip}/" artifacts/kubeadm/upgrade-master.sh
      cat artifacts/kubeadm/upgrade-master.sh | grep NEW_VERSION
    EOF
  }

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("${path.module}/../deploy/.ssh-default/id_rsa.key")
    host        = "${var.prefixIP}.${each.value.octetIP}"
  }

  provisioner "file" {
  source      = "artifacts/kubeadm/upgrade-master.sh"
  destination = "/root/kubeadm/upgrade-master.sh"
  }

  provisioner "file" {
  source      = "artifacts/kubeadm/${var.new_version}"
  destination = "/root/kubeadm"
  }

  provisioner "remote-exec" {
  inline = [<<EOF
      chmod +x ./kubeadm/upgrade-master.sh
      sudo ./kubeadm/upgrade-master.sh
    EOF
    ]
  }

} 

resource "terraform_data" "upgrade_master_member" {
  depends_on = [terraform_data.upgrade_master_init]

  for_each =  {for key, val in var.kubeadm_nodes:
               key => val if val.role == "master-member"}

  provisioner "local-exec" {
    command = <<EOF
      echo "Create upgrade-master.sh"
      sed -i "s/NEW_VERSION=.*/NEW_VERSION=${var.new_version}/" artifacts/kubeadm/upgrade-master.sh
      sed -i "s/MASTER_IP=.*/MASTER_IP=${var.master_ip}/" artifacts/kubeadm/upgrade-master.sh
      cat artifacts/kubeadm/upgrade-master.sh | grep NEW_VERSION
    EOF
  }

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("${path.module}/../deploy/.ssh-default/id_rsa.key")
    host        = "${var.prefixIP}.${each.value.octetIP}"
  }

  provisioner "file" {
  source      = "artifacts/kubeadm/upgrade-master.sh"
  destination = "/root/kubeadm/upgrade-master.sh"
  }

  provisioner "file" {
  source      = "artifacts/kubeadm/${var.new_version}"
  destination = "/root/kubeadm"
  }

  provisioner "remote-exec" {
  inline = [<<EOF
      chmod +x ./kubeadm/upgrade-master.sh
      sudo ./kubeadm/upgrade-master.sh
    EOF
    ]
  }

} 
resource "terraform_data" "upgrade-worker" {
  depends_on = [terraform_data.upgrade_master_init]

  for_each =  {for key, val in var.kubeadm_nodes:
               key => val if val.role == "worker"}

  provisioner "local-exec" {
    command = <<EOF
      echo "Create upgrade-worker.sh"
      sed -i "s/NEW_VERSION=.*/NEW_VERSION=${var.new_version}/" artifacts/kubeadm/upgrade-worker.sh
      cat artifacts/kubeadm/upgrade-worker.sh | grep NEW_VERSION
    EOF
  }

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("${path.module}/../deploy/.ssh-default/id_rsa.key")
    host        = "${var.prefixIP}.${each.value.octetIP}"
  }

  provisioner "file" {
  source      = "artifacts/kubeadm/upgrade-worker.sh"
  destination = "/root/kubeadm/upgrade-worker.sh"
  }

  provisioner "file" {
  source      = "artifacts/kubeadm/${var.new_version}"
  destination = "/root/kubeadm"
  }

  provisioner "remote-exec" {
  inline = [<<EOF
      chmod +x ./kubeadm/upgrade-worker.sh
      sudo ./kubeadm/upgrade-worker.sh
    EOF
    ]
  }

} 
