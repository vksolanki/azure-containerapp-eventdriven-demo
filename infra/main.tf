# Local variables for naming
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Environment = var.environment
  })
}

# Resource Group
module "resource_group" {
  source = "./modules/resource_group"

  resource_group_name = "${local.name_prefix}-rg"
  location            = var.location
  tags                = local.common_tags
}

# Container App (created first to get principal ID for RBAC)
module "container_app" {
  source = "./modules/container_app"

  container_app_name       = "${local.name_prefix}-app"
  container_app_env_name   = "${local.name_prefix}-env"
  container_registry_name  = "${replace(local.name_prefix, "-", "")}acr"
  resource_group_name      = module.resource_group.name
  location                 = module.resource_group.location

  tags = local.common_tags

  depends_on = [module.resource_group]
}

# Key Vault
module "key_vault" {
  source = "./modules/key_vault"

  key_vault_name         = "${local.name_prefix}-kv"
  resource_group_name    = module.resource_group.name
  location               = module.resource_group.location
  function_principal_id  = module.container_app.principal_id
  tags                   = local.common_tags

  depends_on = [module.container_app]
}

# Store Event Grid key in Key Vault
resource "azurerm_key_vault_secret" "eventgrid_key" {
  name         = "EventGridKey"
  value        = module.event_grid.primary_access_key
  key_vault_id = module.key_vault.id

  depends_on = [module.key_vault]
}

# Service Bus
module "service_bus" {
  source = "./modules/service_bus"

  namespace_name        = "${local.name_prefix}-servicebus"
  resource_group_name   = module.resource_group.name
  location              = module.resource_group.location
  sku                   = "Standard"
  queue_name            = "order-queue"
  topic_name            = "order-topic"
  subscription_name     = "order-subscription"
  function_principal_id = module.container_app.principal_id
  tags                  = local.common_tags

  depends_on = [module.resource_group, module.container_app]
}

# Event Grid
module "event_grid" {
  source = "./modules/event_grid"

  topic_name            = "${local.name_prefix}-eg-topic"
  resource_group_name   = module.resource_group.name
  location              = module.resource_group.location
  function_principal_id = module.container_app.principal_id
  container_app_fqdn    = module.container_app.fqdn
  tags                  = local.common_tags

  depends_on = [module.resource_group, module.container_app]
}

# API Management
module "apim" {
  source = "./modules/apim"

  apim_name           = "${local.name_prefix}-apim"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  publisher_name      = var.apim_publisher_name
  publisher_email     = var.apim_publisher_email
  function_app_url    = "https://${module.container_app.fqdn}"
  tags                = local.common_tags

  depends_on = [module.resource_group, module.container_app]
}

# Update Container App environment variables after other resources are created
# Using null_resource with Azure CLI since env vars can't be set initially due to circular dependency
resource "null_resource" "container_app_env_vars" {
  triggers = {
    servicebus_namespace = module.service_bus.namespace_name
    eventgrid_endpoint  = module.event_grid.endpoint
    keyvault_uri        = module.key_vault.vault_uri
  }

  provisioner "local-exec" {
    command = <<-EOT
      az containerapp update `
        --name ${module.container_app.name} `
        --resource-group ${module.resource_group.name} `
        --set-env-vars `
          "ServiceBusConnection__fullyQualifiedNamespace=${module.service_bus.namespace_name}.servicebus.windows.net" `
          "EventGridTopicEndpoint=${module.event_grid.endpoint}" `
          "KeyVaultUri=${module.key_vault.vault_uri}"
    EOT
    interpreter = ["PowerShell", "-Command"]
  }

  depends_on = [
    module.container_app,
    module.service_bus,
    module.event_grid,
    module.key_vault,
    azurerm_key_vault_secret.eventgrid_key
  ]
}
