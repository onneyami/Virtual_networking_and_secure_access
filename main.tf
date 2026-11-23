# Fetching existing resource group in Azure
data "azurerm_resource_group" "rg" {
  name = var.resource_group.name
}