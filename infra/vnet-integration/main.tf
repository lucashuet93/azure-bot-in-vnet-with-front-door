terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_resource_group" "resource_group" {
  name = var.resource_group_name
}

data "azurerm_windows_web_app" "app_service" {
  name                = var.app_service_name
  resource_group_name = data.azurerm_resource_group.resource_group.name
}

data "azurerm_virtual_network" "virtual_network" {
  name                = var.virtual_network_name
  resource_group_name = data.azurerm_resource_group.resource_group.name
}

resource "azurerm_private_dns_zone" "sites_private_dns_zone" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = data.azurerm_resource_group.resource_group.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "sites_private_link" {
  name                  = "${var.prefix}sitesprivatelink"
  resource_group_name   = data.azurerm_resource_group.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.sites_private_dns_zone.name
  virtual_network_id    = data.azurerm_virtual_network.virtual_network.id
}

resource "azurerm_private_endpoint" "sites_private_endpoint" {
  name                = "${var.prefix}sitesprivateendpoint"
  resource_group_name = data.azurerm_resource_group.resource_group.name
  location            = data.azurerm_resource_group.resource_group.location

  subnet_id = var.privte_endpoint_subnet_id

  private_service_connection {
    name                           = "sitesprivateserviceconnection"
    private_connection_resource_id = data.azurerm_windows_web_app.app_service.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sitesprivatednszonegroup"
    private_dns_zone_ids = [azurerm_private_dns_zone.sites_private_dns_zone.id]
  }
}
