# Log Analytics: donde caen los registros de operaciones del share.
resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-ehc-${var.entorno}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.etiquetas
}

# Registros del servicio de ficheros (lecturas, escrituras y borrados) hacia Log Analytics.
resource "azurerm_monitor_diagnostic_setting" "registros_ficheros" {
  name                       = "diag-ficheros"
  target_resource_id         = "${azurerm_storage_account.sa.id}/fileServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }
}

# Grupo de acción: a quién se avisa. El email viene de una variable.
resource "azurerm_monitor_action_group" "avisos" {
  name                = "ag-ehc-avisos"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "ehcavisos"
  tags                = local.etiquetas

  email_receiver {
    name                    = "propietario"
    email_address           = var.email_alertas
    use_common_alert_schema = true
  }
}

# Alerta: si en 15 minutos se borran o renombran más de 30 ficheros, avisa por email.
# Es la señal típica de un ransomware: muchos ficheros tocados de golpe.
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "borrado_masivo" {
  name                 = "alerta-borrado-masivo"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  description          = "Muchos ficheros borrados o renombrados de golpe en el servidor de ficheros."
  severity             = 2
  scopes               = [azurerm_log_analytics_workspace.law.id]
  evaluation_frequency = "PT5M"
  window_duration      = "PT15M"
  tags                 = local.etiquetas

  criteria {
    query                   = <<-KQL
      StorageFileLogs
      | where TimeGenerated > ago(15m)
      | where OperationName in~ ("DeleteFile", "RenameFile", "PutRange")
      | summarize Operaciones = count()
    KQL
    time_aggregation_method = "Total"
    metric_measure_column   = "Operaciones"
    operator                = "GreaterThan"
    threshold               = 30
  }

  action {
    action_groups = [azurerm_monitor_action_group.avisos.id]
  }

  depends_on = [azurerm_monitor_diagnostic_setting.registros_ficheros]
}
