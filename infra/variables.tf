variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "orderdemo"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "vs-dev"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "UK South"
}

variable "apim_publisher_name" {
  description = "Publisher name for API Management"
  type        = string
  default     = "Order Demo Publisher"
}

variable "apim_publisher_email" {
  description = "Publisher email for API Management"
  type        = string
  default     = "vikas.solanki@civica.com"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "OrderDemo"
    ManagedBy   = "Terraform"
  }
}
