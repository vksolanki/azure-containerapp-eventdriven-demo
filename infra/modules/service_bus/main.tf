resource "azurerm_servicebus_namespace" "main" {
  name                = var.namespace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku

  tags = var.tags
}

# Queue
resource "azurerm_servicebus_queue" "order_queue" {
  name         = var.queue_name
  namespace_id = azurerm_servicebus_namespace.main.id

  max_delivery_count                     = 10
  dead_lettering_on_message_expiration   = true
  default_message_ttl                    = "P14D" # 14 days
  lock_duration                          = "PT1M" # 1 minute
  requires_duplicate_detection           = false
  requires_session                       = false
}

# Topic
resource "azurerm_servicebus_topic" "order_topic" {
  name         = var.topic_name
  namespace_id = azurerm_servicebus_namespace.main.id

  requires_duplicate_detection         = false
  default_message_ttl                  = "P14D"
  max_size_in_megabytes               = 1024
}

# Topic Subscription
resource "azurerm_servicebus_subscription" "order_subscription" {
  name               = var.subscription_name
  topic_id           = azurerm_servicebus_topic.order_topic.id
  max_delivery_count = 10
  lock_duration      = "PT1M"
  dead_lettering_on_message_expiration = true
  requires_session   = false
}

# RBAC: Grant Function App Service Bus Data Sender role
resource "azurerm_role_assignment" "function_sb_sender" {
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = var.function_principal_id
}

# RBAC: Grant Function App Service Bus Data Receiver role
resource "azurerm_role_assignment" "function_sb_receiver" {
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = var.function_principal_id
}
