variable "prefixIP" { default = "100.100.100" }

variable "master_ip" { default = "100.100.100.101" }

variable "new_version" { default = "v1.27.6" }

variable "kubeadm_nodes" { 

  type = map(object({ role = string, octetIP = string , vcpu = number, memoryMB = number, incGB = number}))
  default = { 
              kubeadm-master-1 = { role = "master-init",   octetIP = "101" , vcpu = 2, memoryMB = 1024 * 8, incGB = 30},
              kubeadm-master-2 = { role = "master-member", octetIP = "102" , vcpu = 2, memoryMB = 1024 * 8, incGB = 30}
              kubeadm-worker-1 = { role = "worker",        octetIP = "201" , vcpu = 2, memoryMB = 1024 * 8, incGB = 30}
  }
}
