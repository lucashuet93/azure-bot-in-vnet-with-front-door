variable "prefix" {
  description = "Value to be prefixed to all resources"
}

variable "location" {
  description = "Location for all resources"
  default = "eastus2"
}

variable "admin_username" {
  description = "Username to connect to VM"
}

variable "admin_password" {
  description = "Password to connect to VM"
  sensitive = true
}