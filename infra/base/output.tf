output "resource_group_name" {
  value = azurerm_resource_group.resource_group.name
}

output "app_service_name" {
  value = azurerm_windows_web_app.web_app.name
}

output "app_service_hostname" {
  value = azurerm_windows_web_app.web_app.default_hostname
}

output "virtual_network_name" {
  value = azurerm_virtual_network.virtual_network.name
}

output "virtual_network_private_endpoint_subnet_id" {
  value = azurerm_subnet.private_endpoint_subnet.id
}

output "virtual_network_app_service_integration_subnet_id" {
  value = azurerm_subnet.app_service_integration_subnet.id
}

output "user_assigned_managed_identity_client_id" {
  value = azurerm_user_assigned_identity.user_assigned_managed_identity.client_id
}

output "user_assigned_managed_identity_tenant_id" {
  value = azurerm_user_assigned_identity.user_assigned_managed_identity.tenant_id
}