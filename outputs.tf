output "vm_private_ips" {
  description = "Private IP addresses of the deployed VMs"
  value = {
    for k, vm in azurerm_linux_virtual_machine.vm : k => vm.private_ip_address
  }
}

output "vm_ids" {
  description = "Resource IDs of the deployed VMs for Network Watcher diagnostics"
  value = {
    for k, vm in azurerm_linux_virtual_machine.vm : k => vm.id
  }
}