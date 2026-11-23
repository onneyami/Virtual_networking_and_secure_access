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

# Ready-to-run Azure CLI commands for on-demand Connection Troubleshoot & IP Flow Verify
output "network_watcher_cli_checks" {
  description = "Run these commands after terraform apply to execute on-demand diagnostics"
  value = {
    # Connection Troubleshoot: verifies end-to-end reachability on allowed app port 8080
    troubleshoot_allowed_8080 = "az network watcher test-connectivity --resource-group ${data.azurerm_resource_group.rg.name} --source-resource ${azurerm_linux_virtual_machine.vm["first"].name} --dest-resource ${azurerm_linux_virtual_machine.vm["second"].name} --dest-port 8080 --protocol Tcp"

    # Connection Troubleshoot: verifies port 80 is blocked by DenyAllInbound (priority 4096)
    troubleshoot_blocked_80 = "az network watcher test-connectivity --resource-group ${data.azurerm_resource_group.rg.name} --source-resource ${azurerm_linux_virtual_machine.vm["first"].name} --dest-resource ${azurerm_linux_virtual_machine.vm["second"].name} --dest-port 80 --protocol Tcp"

    # IP Flow Verify: evaluates NSG rules on VM2's NIC directly without needing a listening service
    ip_flow_verify_8080 = "az network watcher test-ip-flow --resource-group ${data.azurerm_resource_group.rg.name} --vm ${azurerm_linux_virtual_machine.vm["second"].name} --direction Inbound --protocol TCP --local ${azurerm_linux_virtual_machine.vm["second"].private_ip_address}:8080 --remote ${azurerm_linux_virtual_machine.vm["first"].private_ip_address}:50000"
  }
}