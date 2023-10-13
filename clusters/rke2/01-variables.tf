variable "password" { default = "linux" }

variable "prefixIP" { default = "17.10.10" }

variable "network_name" {default = "nat10" }

variable "master_ip" { default = "17.10.10.11" }

variable "dns_domain" { default = "kubeworks.net" }

variable "diskPool" { default = "default" }

variable "qemu_connect" { default = "qemu:///system" }


variable "rke2_nodes" { 

  type = map(object({ role = string, octetIP = string , vcpu = number, memoryMB = number, incGB = number}))
  default = { 
              rke2-master-1 = { role = "master", octetIP = "11" , vcpu = 2, memoryMB = 1024 * 8, incGB = 30},
              rke2-master-2 = { role = "master", octetIP = "12" , vcpu = 2, memoryMB = 1024 * 8, incGB = 30},
              rke2-worker-2 = { role = "worker", octetIP = "21" , vcpu = 2, memoryMB = 1024 * 8, incGB = 30}
  }
}
