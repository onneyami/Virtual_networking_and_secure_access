locals {
  vm_configs = {
    first = {
      vm_name   = "vm-first-vnet"
      nic_name  = "nic-vm-first"
      subnet_id = azurerm_subnet.subnet-for-first-vnet.id
    }
    second = {
      vm_name   = "vm-second-vnet"
      nic_name  = "nic-vm-second"
      subnet_id = azurerm_subnet.subnet-for-second-vnet.id
    }
  }
}

resource "azurerm_network_interface" "vm_nic" {
  for_each            = local.vm_configs
  name                = each.value.nic_name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = each.value.subnet_id
    private_ip_address_allocation = "Dynamic"
    # Omitting public_ip_address_id enforces private-only connectivity
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  for_each                        = local.vm_configs
  name                            = each.value.vm_name
  resource_group_name             = data.azurerm_resource_group.rg.name
  location                        = data.azurerm_resource_group.rg.location
  size                            = "Standard_B1s"
  admin_username                  = var.admin_username
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.vm_nic[each.key].id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = {
    environment = "lab"
  }
}

# Required for Azure Network Watcher Connection Troubleshoot & Connection Monitor
resource "azurerm_virtual_machine_extension" "network_watcher_agent" {
  for_each                   = local.vm_configs
  name                       = "NetworkWatcherAgentLinux"
  virtual_machine_id         = azurerm_linux_virtual_machine.vm[each.key].id
  publisher                  = "Microsoft.Azure.NetworkWatcher"
  type                       = "NetworkWatcherAgentLinux"
  type_handler_version       = "1.4"
  auto_upgrade_minor_version = true
}