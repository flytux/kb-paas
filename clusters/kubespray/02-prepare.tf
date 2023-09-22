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

data "template_file" "cloud_inits" {
  for_each = var.kubespray_nodes
  template = file("${path.module}/artifacts/config/cloud_init.cfg")
  vars = {
    hostname = each.key
    fqdn     = "${each.key}.${var.network_domain_name}"
    password = var.password
    public_key = "${tls_private_key.generic-ssh-key.public_key_openssh}"
  }
}

# OS images for libvirt VMs
resource "libvirt_volume" "os_images" {
  for_each = var.kubespray_nodes
  name   = "${each.key}.qcow2"
  pool   = var.disk_pool
  source = "artifacts/images/${var.cloud_image_name}"
  format = "qcow2"

# Extend libvirt primary volume
  provisioner "local-exec" {
    command = <<EOF
      echo "Increment disk size by ${each.value.incGB}GB"
      sleep 10
      poolPath=$(virsh --connect ${var.qemu_connect} pool-dumpxml ${var.disk_pool} | grep -Po '<path>\K[^<]+')
      sudo qemu-img resize $poolPath/${each.key}.qcow2 +${each.value.incGB}G
      sudo chgrp libvirt $poolPath/${each.key}.qcow2
      sudo chmod g+w $poolPath/${each.key}.qcow2
    EOF
  }
}

# Create cloud init disk
resource "libvirt_cloudinit_disk" "cloudinit_disks" {
  for_each = var.kubespray_nodes
  name           = "${each.key}-cloudinit.iso"
  pool           = var.disk_pool
  user_data      = data.template_file.cloud_inits[each.key].rendered
}

resource "libvirt_network" "nat" {

  name = "${var.network_name}"
  mode = "nat"
  addresses = [ "${var.prefix_ip}.0/24" ]

  domain = "${var.network_domain_name}"

  dns {
    enabled = true
    local_only = true
  }
  dhcp { enabled = false }
  autostart = true
}

