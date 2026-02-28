variable "namespace_name" {
  description = "Name of the Service Bus namespace"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "sku" {
  description = "Service Bus SKU (Basic, Standard, Premium)"
  type        = string
  default     = "Standard"
}

variable "queue_name" {
  description = "Name of the Service Bus queue"
  type        = string
  default     = "order-queue"
}

variable "topic_name" {
  description = "Name of the Service Bus topic"
  type        = string
  default     = "order-topic"
}

variable "subscription_name" {
  description = "Name of the Service Bus topic subscription"
  type        = string
  default     = "order-subscription"
}

variable "function_principal_id" {
  description = "Principal ID of the Function App managed identity"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
