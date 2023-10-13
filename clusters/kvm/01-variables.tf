variable "password" { default = "linux" }

variable "network_name" { default = "nat17" }

variable "prefix_ip" { default = "17.10.10" }

variable "master_ip" { default = "17.10.10.11" }

variable "network_domain_name" { default = "kubeworks.net" }

variable "cloud_image_name" { default = "focal-server-cloudimg-amd64-disk-kvm.img" }

variable "disk_pool" { default = "default" }

variable "qemu_connect" { default = "qemu:///system" }

variable "join_cmd" { default = "$(ssh -i $HOME/.ssh/id_rsa.key -o StrictHostKeyChecking=no 17.10.10.11 -- cat join_cmd)" }

variable "kubeadm_home" { default = "artifacts/kubeadm" }

variable "yum_ip" { default = "10.10.10.101" }

variable "yum_domain" { default = "repo.kw01" }

variable "registry_domain" { default = "docker.kw01" }

variable "kubeadm_nodes" { 

  type = map(object({ role = string, octetIP = string , vcpu = number, memoryMB = number, incGB = number}))
  default = { 
              kw-master-1 = { role = "master-init",   octetIP = "11" , vcpu = 2, memoryMB = 1024 * 8, incGB = 30},
              kw-worker-1 = { role = "worker",        octetIP = "21" , vcpu = 2, memoryMB = 1024 * 8, incGB = 30}
              kw-master-2 = { role = "master-member", octetIP = "12" , vcpu = 2, memoryMB = 1024 * 8, incGB = 30}
  }
}
