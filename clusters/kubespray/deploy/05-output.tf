output "nodes" {
  value = zipmap(
    values(libvirt_domain.kubespray_node)[*].name,
    values(libvirt_domain.kubespray_node)[*].vcpu
  )
}
