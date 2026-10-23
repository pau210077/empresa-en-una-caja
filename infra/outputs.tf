output "grupo_recursos" {
  description = "Nombre del grupo de recursos (lo que se borra al final)."
  value       = azurerm_resource_group.rg.name
}

output "cuenta_almacenamiento" {
  description = "Cuenta de almacenamiento con los tres shares."
  value       = azurerm_storage_account.sa.name
}

output "shares" {
  description = "Shares por departamento."
  value       = [azurerm_storage_share.contabilidad.name, azurerm_storage_share.laboral.name, azurerm_storage_share.direccion.name]
}

output "vm" {
  description = "Nombre de la VM (administrar con Bastion o Run Command)."
  value       = azurerm_windows_virtual_machine.srv.name
}

output "log_analytics" {
  description = "Nombre del workspace de Log Analytics."
  value       = azurerm_log_analytics_workspace.law.name
}
