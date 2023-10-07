variable "password" { default = "linux" }

variable "network_name" { default = "nat100" }

variable "prefix_ip" { default = "100.100.100" }

variable "master_ip" { default = "100.100.100.101" }

variable "network_domain_name" { default = "kubeworks.net" }

variable "cloud_image_name" { default = "Rocky-8-GenericCloud-8.6.20220702.0.x86_64.qcow2" }

variable "disk_pool" { default = "default" }

variable "qemu_connect" { default = "qemu:///system" }

variable "join_cmd" { default = "$(ssh -i $HOME/.ssh/id_rsa.key -o StrictHostKeyChecking=no 100.100.100.101 -- cat join_cmd)" }

variable "kubeadm_home" { default = "artifacts/kubeadm" }

variable "yum_ip" { default = "10.10.10.101" }

variable "yum_domain" { default = "repo.kw01" }

variable "registry_domain" { default = "docker.kw01" }

variable "kubeadm_nodes" { 

  type = map(object({ role = string, octetIP = string , vcpu = number, memoryMB = number, incGB = number}))
  default = { 
              kb-master-1 = { role = "master-init",   octetIP = "101" , vcpu = 2, memoryMB = 1024 * 8, incGB = 30},
              kb-worker-1 = { role = "worker",        octetIP = "201" , vcpu = 2, memoryMB = 1024 * 8, incGB = 30}
              kb-master-2 = { role = "master-member", octetIP = "102" , vcpu = 2, memoryMB = 1024 * 8, incGB = 30}
  }
}
