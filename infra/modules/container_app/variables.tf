variable "container_app_name" {
  description = "Name of the Container App"
  type        = string
}

variable "container_app_env_name" {
  description = "Name of the Container App Environment"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "container_registry_name" {
  description = "Name of the Azure Container Registry"
  type        = string
}

variable "image_name" {
  description = "Container image name"
  type        = string
  default     = "orderdemo:latest"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
