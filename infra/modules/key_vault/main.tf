data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Enable RBAC authorization instead of access policies
  enable_rbac_authorization  = true
  
  purge_protection_enabled   = false
  soft_delete_retention_days = 7

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

# Grant the current user Key Vault Administrator role
resource "azurerm_role_assignment" "current_user_kv_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Grant Function App Managed Identity access to Key Vault Secrets
resource "azurerm_role_assignment" "function_kv_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.function_principal_id
}

# Wait for RBAC permissions to propagate
resource "time_sleep" "wait_for_rbac" {
  depends_on = [
    azurerm_role_assignment.current_user_kv_admin,
    azurerm_role_assignment.function_kv_secrets_user
  ]

  create_duration = "30s"
}
