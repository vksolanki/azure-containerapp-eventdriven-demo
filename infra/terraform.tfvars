# Terraform variables configuration
# Copy this file to terraform.tfvars and customize the values

project_name = "orderdemo"
environment  = "dev"
location     = "uksouth"

apim_publisher_name  = "Order Demo Publisher"
apim_publisher_email = "admin@orderdemo.com"

tags = {
  Project     = "OrderDemo"
  ManagedBy   = "Terraform"
  Owner       = "DevTeam"
}
