output "name" {
  description = "Name of the Container App"
  value       = azurerm_container_app.main.name
}

output "id" {
  description = "ID of the Container App"
  value       = azurerm_container_app.main.id
}

output "principal_id" {
  description = "Principal ID of the Container App managed identity"
  value       = azurerm_container_app.main.identity[0].principal_id
}

output "fqdn" {
  description = "Fully qualified domain name of the Container App"
  value       = azurerm_container_app.main.ingress[0].fqdn
}

output "latest_revision_fqdn" {
  description = "Latest revision FQDN"
  value       = azurerm_container_app.main.latest_revision_fqdn
}

output "container_registry_login_server" {
  description = "Login server for the container registry"
  value       = azurerm_container_registry.acr.login_server
}

output "container_registry_name" {
  description = "Name of the container registry"
  value       = azurerm_container_registry.acr.name
}
