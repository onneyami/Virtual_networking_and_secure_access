resource "azurerm_subnet" "subnet-for-first-vnet" {
  name                 = "SubnetForFirstVnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet_first.name
  address_prefixes     = ["10.10.1.0/26"]
}

resource "azurerm_subnet" "subnet-for-second-vnet" {
  name                 = "SubnetForSecondVnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet_second.name
  address_prefixes     = ["10.20.1.0/26"]
}

