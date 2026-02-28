output "resource_group_name" {
  description = "Name of the resource group"
  value       = module.resource_group.name
}

output "container_app_name" {
  description = "Name of the Container App"
  value       = module.container_app.name
}

output "container_app_url" {
  description = "URL of the Container App"
  value       = "https://${module.container_app.fqdn}"
}

output "container_app_fqdn" {
  description = "Fully qualified domain name of the Container App"
  value       = module.container_app.fqdn
}

output "container_app_principal_id" {
  description = "Managed Identity Principal ID of the Container App"
  value       = module.container_app.principal_id
}

output "container_registry_login_server" {
  description = "Container Registry login server"
  value       = module.container_app.container_registry_login_server
}

output "apim_gateway_url" {
  description = "API Management gateway URL"
  value       = module.apim.gateway_url
}

output "apim_order_api_url" {
  description = "Full URL for the Order API through APIM"
  value       = "${module.apim.gateway_url}/orders/create"
}

output "servicebus_namespace" {
  description = "Service Bus namespace name"
  value       = module.service_bus.namespace_name
}

output "service_bus_queue_name" {
  description = "Service Bus queue name"
  value       = module.service_bus.queue_name
}

output "service_bus_topic_name" {
  description = "Service Bus topic name"
  value       = module.service_bus.topic_name
}

output "service_bus_subscription_name" {
  description = "Service Bus topic subscription name"
  value       = module.service_bus.subscription_name
}

output "event_grid_topic_name" {
  description = "Event Grid topic name"
  value       = module.event_grid.name
}

output "event_grid_topic_endpoint" {
  description = "Event Grid topic endpoint"
  value       = module.event_grid.endpoint
}

output "event_grid_endpoint" {
  description = "Event Grid topic endpoint (alias)"
  value       = module.event_grid.endpoint
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = module.key_vault.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = module.key_vault.vault_uri
}
