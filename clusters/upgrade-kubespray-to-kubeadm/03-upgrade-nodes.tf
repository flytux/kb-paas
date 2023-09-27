resource "local_file" "prepare-upgrade-master" {
    content     = templatefile("${path.module}/artifacts/templates/upgrade-master.sh", {
                    master_ip = var.master_ip
                   })
    filename = "${path.module}/artifacts/kubeadm/scripts/upgrade-master.sh"
}

resource "local_file" "prepare-upgrade-worker" {
    depends_on = [local_file.prepare-upgrade-master]
    content     = templatefile("${path.module}/artifacts/templates/upgrade-worker.sh", {
                    master_ip = var.master_ip
                   })
    filename = "${path.module}/artifacts/kubeadm/scripts/upgrade-worker.sh" 
}

resource "terraform_data" "prepare_script" {
  depends_on = [local_file.prepare-upgrade-worker]

  provisioner "local-exec" {
  command = <<EOF
    echo "Config upgrade-master.sh"
    sed -i "s/NEW_VERSION=.*/NEW_VERSION=${var.new_version}/" artifacts/kubeadm/scripts/upgrade-master.sh
    sed -i "s/MASTER_IP=.*/MASTER_IP=${var.master_ip}/" artifacts/kubeadm/scripts/upgrade-master.sh
    cat artifacts/kubeadm/scripts/upgrade-master.sh | grep NEW_VERSION

    echo "Config upgrade-worker.sh"
    sed -i "s/NEW_VERSION=.*/NEW_VERSION=${var.new_version}/" artifacts/kubeadm/scripts/upgrade-worker.sh
    sed -i "s/MASTER_IP=.*/MASTER_IP=${var.master_ip}/" artifacts/kubeadm/scripts/upgrade-worker.sh
    cat artifacts/kubeadm/scripts/upgrade-worker.sh | grep NEW_VERSION
  EOF
  }
}

resource "terraform_data" "upgrade_master_init" {
  depends_on = [terraform_data.prepare_script]

  for_each =  {for key, val in var.kubeadm_nodes:
               key => val if val.role == "master-init"}

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("${path.module}/../kubespray/.ssh-default/id_rsa.key")
    host        = "${var.prefix_ip}.${each.value.octetIP}"
  }

  provisioner "file" {
  source      = "artifacts/kubeadm/scripts/upgrade-master.sh"
  destination = "/root/kubeadm/scripts/upgrade-master.sh"
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
    private_key = file("${path.module}/../kubespray/.ssh-default/id_rsa.key")
    host        = "${var.prefix_ip}.${each.value.octetIP}"
  }

  provisioner "file" {
  source      = "artifacts/kubeadm/scripts/upgrade-master.sh"
  destination = "/root/kubeadm/scripts/upgrade-master.sh"
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
  depends_on = [terraform_data.upgrade_master_init]

  for_each =  {for key, val in var.kubeadm_nodes:
               key => val if val.role == "worker"}

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("${path.module}/../kubespray/.ssh-default/id_rsa.key")
    host        = "${var.prefix_ip}.${each.value.octetIP}"
  }

  provisioner "file" {
  source      = "artifacts/kubeadm/scripts/upgrade-worker.sh"
  destination = "/root/kubeadm/scripts/upgrade-worker.sh"
  }

  provisioner "remote-exec" {
  inline = [<<EOF

      chmod +x ./kubeadm/scripts/upgrade-worker.sh
      sudo ./kubeadm/scripts/upgrade-worker.sh

    EOF
    ]
  }

} 
