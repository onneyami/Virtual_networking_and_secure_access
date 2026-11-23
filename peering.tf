resource "azurerm_virtual_network_peering" "first_to_second" {
  name                      = "first-vnet-to-second-vnet"
  resource_group_name       = data.azurerm_resource_group.rg.name
  virtual_network_name      = data.azurerm_virtual_network.vnet_first.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_second.id
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "second_to_first" {
  name                      = "second-vnet-to-first-vnet"
  resource_group_name       = data.azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet_second.name
  remote_virtual_network_id = data.azurerm_virtual_network.vnet_first.id
  allow_virtual_network_access = true
}