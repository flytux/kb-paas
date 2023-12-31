variable "prefix_ip" { default = "101.101.101" }

variable "master_ip" { default = "101.101.101.101" }

variable "new_version" { default = "v1.27.6" }

variable "registry_ip" { default = "10.10.10.101" }

variable "yum_ip" { default = "10.10.10.101" }

variable "registry_domain" { default = "docker.kw01" }

variable "yum_domain" { default = "repo.kw01" }

variable "kubeadm_nodes" { 

  type = map(object({ role = string, octetIP = string , vcpu = number, memoryMB = number, incGB = number}))
  default = { 
              kubespray-master-1 = { role = "master-init",   octetIP = "101" , vcpu = 2, memoryMB = 1024 * 8, incGB = 30},
              kubespray-master-2 = { role = "master-member", octetIP = "102" , vcpu = 2, memoryMB = 1024 * 8, incGB = 30}
              kubespray-worker-1 = { role = "worker",        octetIP = "201" , vcpu = 2, memoryMB = 1024 * 8, incGB = 30}
  }
}
