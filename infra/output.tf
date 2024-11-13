output "resource_group_name" {
  value = azurerm_resource_group.resource_group.name
}

output "app_service_name" {
  value = azurerm_windows_web_app.web_app.name
}

output "user_assigned_managed_identity_client_id" {
  value = azurerm_user_assigned_identity.user_assigned_managed_identity.client_id
}

output "user_assigned_managed_identity_tenant_id" {
  value = azurerm_user_assigned_identity.user_assigned_managed_identity.tenant_id
}