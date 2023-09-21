output "nodes" {
  value = zipmap(
    values(libvirt_domain.kubeadm_nodes)[*].name,
    values(libvirt_domain.kubeadm_nodes)[*].vcpu
  )
}
