resource "azurerm_virtual_network" "vnet_first" {
  name                = "vnet-first"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  address_space       = ["10.10.0.0/16"]
}

resource "azurerm_virtual_network" "vnet_second" {
  name                = "vnet-second"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  address_space       = ["10.20.0.0/16"]
}