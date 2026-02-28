variable "topic_name" {
  description = "Name of the Event Grid topic"
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

variable "function_principal_id" {
  description = "Principal ID of the Function App managed identity"
  type        = string
}

variable "container_app_fqdn" {
  description = "FQDN of the Container App for webhook subscription"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
