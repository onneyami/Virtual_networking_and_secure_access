# Reference the regional Network Watcher auto-provisioned by Azure
data "azurerm_network_watcher" "regional" {
  name                = "NetworkWatcher_${var.location}"
  resource_group_name = "NetworkWatcherRG"
}

# Declarative continuous connectivity monitoring across the VNet peering
resource "azurerm_network_connection_monitor" "peering_monitor" {
  name               = "cm-vnet-peering-check"
  network_watcher_id = data.azurerm_network_watcher.regional.id
  location           = data.azurerm_network_watcher.regional.location

  endpoint {
    name                 = "vm-first-source"
    target_resource_type = "AzureVM"
    target_resource_id   = azurerm_linux_virtual_machine.vm["first"].id
  }

  endpoint {
    name                 = "vm-second-destination"
    target_resource_type = "AzureVM"
    target_resource_id   = azurerm_linux_virtual_machine.vm["second"].id
  }

  # Tests allowed application traffic (NSG priority 200)
  test_configuration {
    name                      = "tcp-8080-app-allowed"
    protocol                  = "Tcp"
    test_frequency_in_seconds = 60

    tcp_configuration {
      port                = 8080
      trace_route_enabled = true
    }

    success_threshold {
      checks_failed_percent = 0
      round_trip_time_ms    = 100
    }
  }

  # Tests blocked traffic to verify deny-by-default (NSG priority 4096)
  test_configuration {
    name                      = "tcp-80-blocked-check"
    protocol                  = "Tcp"
    test_frequency_in_seconds = 60

    tcp_configuration {
      port = 80
    }
  }

  test_group {
    name                     = "peering-nsg-validation"
    destination_endpoints    = ["vm-second-destination"]
    source_endpoints         = ["vm-first-source"]
    test_configuration_names = ["tcp-8080-app-allowed", "tcp-80-blocked-check"]
  }

  depends_on = [
    azurerm_virtual_machine_extension.network_watcher_agent
  ]
}