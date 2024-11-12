variable "prefix" {
  description = "Value to be prefixed to all resources"
}

variable "location" {
  description = "Location for all resources"
  default = "eastus2"
}

variable "resource_group_name" {
  description = "Name of the resource group"
}

variable "app_service_name" {
  description = "Name of the app service"
}

variable "virtual_network_name" {
  description = "Name of the virtual network"
}

variable "privte_endpoint_subnet_id" {
  description = "ID of the subnet for the private endpoints"
}