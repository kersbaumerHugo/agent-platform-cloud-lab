output "resource_group_name" {
  description = "Name of the local Agent Platform resource group."
  value       = azurerm_resource_group.agent_platform.name
}

output "resource_group_id" {
  description = "ARM resource ID of the local Agent Platform resource group."
  value       = azurerm_resource_group.agent_platform.id
}
