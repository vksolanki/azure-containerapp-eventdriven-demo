variable "apim_name" {
  description = "Name of the API Management instance"
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

variable "publisher_name" {
  description = "Publisher name for APIM"
  type        = string
  default     = "Demo Publisher"
}

variable "publisher_email" {
  description = "Publisher email for APIM"
  type        = string
  default     = "admin@example.com"
}

variable "function_app_url" {
  description = "Function App default hostname"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
