output "key_vault_id" {
  description = "Resource ID of the Key Vault used for Kong bootstrap secrets."
  value       = azurerm_key_vault.main.id
}

output "key_vault_name" {
  description = "Name of the Key Vault used for Kong bootstrap secrets."
  value       = azurerm_key_vault.main.name
}

output "kong_secret_identity_id" {
  description = "Resource ID of the user-assigned identity used by Kong to read Key Vault secrets."
  value       = azurerm_user_assigned_identity.kong_secret_reader.id
}

output "kong_secret_identity_principal_id" {
  description = "Principal ID of the user-assigned identity used by Kong to read Key Vault secrets."
  value       = azurerm_user_assigned_identity.kong_secret_reader.principal_id
}

output "bootstrap_writer_identity_client_id" {
  description = "Client ID of the user-assigned identity used by the ACA bootstrap job to write Key Vault secrets."
  value       = azurerm_user_assigned_identity.bootstrap_writer.client_id
}

output "bootstrap_writer_identity_id" {
  description = "Resource ID of the user-assigned identity used by the ACA bootstrap job to write Key Vault secrets."
  value       = azurerm_user_assigned_identity.bootstrap_writer.id
}

output "vault_uri" {
  description = "Vault URI used to build versionless Key Vault secret references."
  value       = azurerm_key_vault.main.vault_uri
}
