# Name of existing resource group for data block in main.tf
variable "resource_group_name" {
  type    = string
  default = "rg-andrei"
}

# Admin source CiDR for nsgs.tf
variable "admin_source_cidr" {
  description = "Trusted source CIDR for SSH management (e.g., AzureBastionSubnet or your public IP/32)"
  type        = string
  default     = "10.10.2.0/26"
}

variable "public_key_path" {
  description = "Path to public SSH key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "admin_username" {
  description = "Admin username for the Linux VMs"
  type        = string
  default     = "azureuser"
}