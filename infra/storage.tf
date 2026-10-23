# Cuenta de almacenamiento. Una sola, barata (LRS = copia local en la región).
resource "azurerm_storage_account" "sa" {
  name                            = "stehc${random_string.sufijo.result}"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true
  tags                            = local.etiquetas
}

# Un recurso compartido por departamento.
# Decisión: son tres shares y no tres carpetas dentro de un share, porque el RBAC de Azure Files
# se asigna a nivel de share. Así cada grupo tiene su permiso sin tocar ACLs de carpeta.
resource "azurerm_storage_share" "contabilidad" {
  name               = "contabilidad"
  storage_account_id = azurerm_storage_account.sa.id
  quota              = 5
  access_tier        = "TransactionOptimized"
}

resource "azurerm_storage_share" "laboral" {
  name               = "laboral"
  storage_account_id = azurerm_storage_account.sa.id
  quota              = 5
  access_tier        = "TransactionOptimized"
}

resource "azurerm_storage_share" "direccion" {
  name               = "direccion"
  storage_account_id = azurerm_storage_account.sa.id
  quota              = 5
  access_tier        = "TransactionOptimized"
}

# RBAC: cada grupo edita su share. Dirección puede leer los tres.
resource "azurerm_role_assignment" "contabilidad_edita" {
  scope                = "${azurerm_storage_account.sa.id}/fileServices/default/shares/${azurerm_storage_share.contabilidad.name}"
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = azuread_group.contabilidad.object_id
}

resource "azurerm_role_assignment" "laboral_edita" {
  scope                = "${azurerm_storage_account.sa.id}/fileServices/default/shares/${azurerm_storage_share.laboral.name}"
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = azuread_group.laboral.object_id
}

resource "azurerm_role_assignment" "direccion_edita" {
  scope                = "${azurerm_storage_account.sa.id}/fileServices/default/shares/${azurerm_storage_share.direccion.name}"
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = azuread_group.direccion.object_id
}

resource "azurerm_role_assignment" "direccion_lee_contabilidad" {
  scope                = "${azurerm_storage_account.sa.id}/fileServices/default/shares/${azurerm_storage_share.contabilidad.name}"
  role_definition_name = "Storage File Data SMB Share Reader"
  principal_id         = azuread_group.direccion.object_id
}

resource "azurerm_role_assignment" "direccion_lee_laboral" {
  scope                = "${azurerm_storage_account.sa.id}/fileServices/default/shares/${azurerm_storage_share.laboral.name}"
  role_definition_name = "Storage File Data SMB Share Reader"
  principal_id         = azuread_group.direccion.object_id
}
