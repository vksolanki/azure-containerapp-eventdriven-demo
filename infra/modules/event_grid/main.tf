resource "azurerm_eventgrid_topic" "main" {
  name                = var.topic_name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Event Grid Subscription - routes events to Container App webhook
resource "azurerm_eventgrid_event_subscription" "webhook" {
  name  = "${var.topic_name}-webhook-subscription"
  scope = azurerm_eventgrid_topic.main.id

  webhook_endpoint {
    url = "https://${var.container_app_fqdn}/api/webhooks/eventgrid"
  }

  included_event_types = [
    "OrderCreated",
    "OrderStatusUpdate",
    "OrderCompleted"
  ]

  retry_policy {
    max_delivery_attempts = 30
    event_time_to_live    = 1440
  }

  labels = ["containerapp", "orders"]
}

# RBAC: Grant Function App Event Grid Data Sender role
resource "azurerm_role_assignment" "function_eg_sender" {
  scope                = azurerm_eventgrid_topic.main.id
  role_definition_name = "EventGrid Data Sender"
  principal_id         = var.function_principal_id
}
