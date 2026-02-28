output "namespace_id" {
  description = "Service Bus namespace ID"
  value       = azurerm_servicebus_namespace.main.id
}

output "namespace_name" {
  description = "Service Bus namespace name"
  value       = azurerm_servicebus_namespace.main.name
}

output "namespace_endpoint" {
  description = "Service Bus namespace endpoint"
  value       = azurerm_servicebus_namespace.main.endpoint
}

output "queue_name" {
  description = "Service Bus queue name"
  value       = azurerm_servicebus_queue.order_queue.name
}

output "topic_name" {
  description = "Service Bus topic name"
  value       = azurerm_servicebus_topic.order_topic.name
}

output "subscription_name" {
  description = "Service Bus topic subscription name"
  value       = azurerm_servicebus_subscription.order_subscription.name
}
