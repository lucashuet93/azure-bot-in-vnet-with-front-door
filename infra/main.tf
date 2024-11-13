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

resource "azurerm_resource_group" "resource_group" {
  name     = "${var.prefix}-rg"
  location = var.location
}

resource "azurerm_user_assigned_identity" "user_assigned_managed_identity" {
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  name                = "${var.prefix}uamsi"
}

resource "azurerm_service_plan" "app_service_plan" {
  name                = var.prefix
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  sku_name            = "S1"
  os_type             = "Windows"
}

resource "azurerm_windows_web_app" "web_app" {
  name                = "${var.prefix}appservice"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  service_plan_id     = azurerm_service_plan.app_service_plan.id

  app_settings = {
    "WEBSITE_NODE_DEFAULT_VERSION" = "10.14.1"
    "MicrosoftAppType"             = "UserAssignedMSI"
    "MicrosoftAppId"               = azurerm_user_assigned_identity.user_assigned_managed_identity.client_id
    "MicrosoftAppPassword"         = ""
    "MicrosoftAppTenantId"         = azurerm_user_assigned_identity.user_assigned_managed_identity.tenant_id
  }

  virtual_network_subnet_id = azurerm_subnet.app_service_integration_subnet.id

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.user_assigned_managed_identity.id
    ]
  }

  site_config {
    websockets_enabled = true
    cors {
      allowed_origins = [
        "https://botservice.hosting.portal.azure.net",
        "https://hosting.onecloud.azure-test.net/"
      ]
      support_credentials = false
    }
  }
}

resource "azurerm_bot_service_azure_bot" "azure_bot_service" {
  name                    = "${var.prefix}botservice"
  resource_group_name     = azurerm_resource_group.resource_group.name
  location                = "global"
  sku                     = "S1"
  endpoint                = "https://${azurerm_cdn_frontdoor_endpoint.frontdoor_endpoint.host_name}/api/messages"
  microsoft_app_id        = azurerm_user_assigned_identity.user_assigned_managed_identity.client_id
  microsoft_app_tenant_id = azurerm_user_assigned_identity.user_assigned_managed_identity.tenant_id
  microsoft_app_msi_id    = azurerm_user_assigned_identity.user_assigned_managed_identity.id
  microsoft_app_type      = "UserAssignedMSI"
}

resource "azurerm_bot_channel_ms_teams" "teams_channel" {
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_bot_service_azure_bot.azure_bot_service.location
  bot_name            = azurerm_bot_service_azure_bot.azure_bot_service.name
}

resource "azurerm_virtual_network" "virtual_network" {
  name                = "${var.prefix}vnet"
  address_space       = ["10.0.0.0/16"]
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
}

resource "azurerm_subnet" "default_subnet" {
  name                 = "DefaultSubnet"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.virtual_network.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "azure_bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.virtual_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "private_endpoint_subnet" {
  name                              = "PrivateEndpointSubnet"
  resource_group_name               = azurerm_resource_group.resource_group.name
  virtual_network_name              = azurerm_virtual_network.virtual_network.name
  address_prefixes                  = ["10.0.2.0/24"]
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_subnet" "app_service_integration_subnet" {
  name                 = "AppServiceIntegrationSubnet"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.virtual_network.name
  address_prefixes     = ["10.0.3.0/24"]

  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_public_ip" "bastion_public_ip" {
  name                = "${var.prefix}publicip"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion_host" {
  name                = "${var.prefix}bastion"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.azure_bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_public_ip.id
  }
}

resource "azurerm_network_security_group" "virtual_machine_nsg" {
  name                = "${var.prefix}nsg"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location

  security_rule {
    name                       = "default-allow-rdp"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "virtual_machine_nic" {
  name                           = "${var.prefix}nic"
  resource_group_name            = azurerm_resource_group.resource_group.name
  location                       = azurerm_resource_group.resource_group.location
  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "vm_nic_configuration"
    subnet_id                     = azurerm_subnet.default_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "virtual_machine_nic_nsg_association" {
  network_interface_id      = azurerm_network_interface.virtual_machine_nic.id
  network_security_group_id = azurerm_network_security_group.virtual_machine_nsg.id
}

resource "azurerm_windows_virtual_machine" "main" {
  name                  = "${var.prefix}vm"
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  resource_group_name   = azurerm_resource_group.resource_group.name
  location              = azurerm_resource_group.resource_group.location
  network_interface_ids = [azurerm_network_interface.virtual_machine_nic.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

resource "azurerm_private_dns_zone" "sites_private_dns_zone" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.resource_group.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "sites_private_link" {
  name                  = "${var.prefix}sitesprivatelink"
  resource_group_name   = azurerm_resource_group.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.sites_private_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.virtual_network.id
}

resource "azurerm_private_endpoint" "sites_private_endpoint" {
  name                = "${var.prefix}sitesprivateendpoint"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location

  subnet_id = azurerm_subnet.private_endpoint_subnet.id

  private_service_connection {
    name                           = "sitesprivateserviceconnection"
    private_connection_resource_id = azurerm_windows_web_app.web_app.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sitesprivatednszonegroup"
    private_dns_zone_ids = [azurerm_private_dns_zone.sites_private_dns_zone.id]
  }
}

resource "azurerm_cdn_frontdoor_profile" "frontdoor" {
  name                = "${var.prefix}frontdoor"
  resource_group_name = azurerm_resource_group.resource_group.name
  sku_name            = "Premium_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_endpoint" "frontdoor_endpoint" {
  name                     = "${var.prefix}appserviceendpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.frontdoor.id
}

resource "azurerm_cdn_frontdoor_origin_group" "frontdoor_origin_group" {
  name                     = "${var.prefix}appserviceorigingroup"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.frontdoor.id

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    path                = "/"
    request_type        = "HEAD"
    protocol            = "Https"
    interval_in_seconds = 100
  }
}

resource "azurerm_cdn_frontdoor_origin" "frontdoor_origin" {
  name                           = "${var.prefix}appserviceorigin"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.frontdoor_origin_group.id
  enabled                        = true
  host_name                      = azurerm_windows_web_app.web_app.default_hostname
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = azurerm_windows_web_app.web_app.default_hostname
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true

  private_link {
    private_link_target_id = azurerm_windows_web_app.web_app.id
    target_type            = "sites"
    location               = azurerm_resource_group.resource_group.location
    request_message        = "Request made via Terraform"
  }
}

resource "azurerm_cdn_frontdoor_route" "frontdoor_route" {
  name                          = "${var.prefix}appserviceroute"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.frontdoor_endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.frontdoor_origin_group.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.frontdoor_origin.id]

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "MatchRequest"
  link_to_default_domain = true
  https_redirect_enabled = true
}
