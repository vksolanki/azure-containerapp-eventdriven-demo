output "id" {
  description = "Key Vault ID"
  value       = azurerm_key_vault.main.id
  depends_on  = [time_sleep.wait_for_rbac]
}

output "name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.main.name
  depends_on  = [time_sleep.wait_for_rbac]
}

output "vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
  depends_on  = [time_sleep.wait_for_rbac]
}
