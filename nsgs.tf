variable "admin_source_cidr" {
  description = "Trusted source CIDR for SSH management (e.g., AzureBastionSubnet or your public IP/32)"
  type        = string
  default     = "10.10.2.0/26"
}

locals {
  nsg_configs = {
    first = {
      name       = "first-vnet-nsg"
      subnet_id  = azurerm_subnet.subnet-for-first-vnet.id
      local_cidr = "10.10.1.0/26"
      peer_cidr  = "10.20.1.0/26"
    }
    second = {
      name       = "second-vnet-nsg"
      subnet_id  = azurerm_subnet.subnet-for-second-vnet.id
      local_cidr = "10.20.1.0/26"
      peer_cidr  = "10.10.1.0/26"
    }
  }
}

resource "azurerm_network_security_group" "vnet_nsg" {
  for_each            = local.nsg_configs
  name                = each.value.name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  # Management Traffic: SSH strictly from trusted admin/Bastion CIDR
  security_rule {
    name                       = "AllowSSHManagement"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_source_cidr
    destination_address_prefix = each.value.local_cidr
  }

  # Application Traffic: App port strictly between peered workload subnets
  security_rule {
    name                       = "AllowAppFromPeerSubnet"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = each.value.peer_cidr
    destination_address_prefix = each.value.local_cidr
  }

  # Deny-by-Default: Overrides Azure's built-in AllowVnetInBound (65000)
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "vnet_nsg_assoc" {
  for_each                  = local.nsg_configs
  subnet_id                 = each.value.subnet_id
  network_security_group_id = azurerm_network_security_group.vnet_nsg[each.key].id
}