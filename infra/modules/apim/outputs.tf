output "id" {
  description = "API Management ID"
  value       = azurerm_api_management.main.id
}

output "name" {
  description = "API Management name"
  value       = azurerm_api_management.main.name
}

output "gateway_url" {
  description = "API Management gateway URL"
  value       = azurerm_api_management.main.gateway_url
}

output "principal_id" {
  description = "Managed Identity principal ID"
  value       = azurerm_api_management.main.identity[0].principal_id
}
