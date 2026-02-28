output "id" {
  description = "Event Grid topic ID"
  value       = azurerm_eventgrid_topic.main.id
}

output "name" {
  description = "Event Grid topic name"
  value       = azurerm_eventgrid_topic.main.name
}

output "endpoint" {
  description = "Event Grid topic endpoint"
  value       = azurerm_eventgrid_topic.main.endpoint
}

output "primary_access_key" {
  description = "Event Grid topic primary access key"
  value       = azurerm_eventgrid_topic.main.primary_access_key
  sensitive   = true
}
