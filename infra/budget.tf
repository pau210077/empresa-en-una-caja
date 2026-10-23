# Presupuesto de 1 € al mes en el grupo de recursos. Avisa al 80 % y al 100 %.
resource "azurerm_consumption_budget_resource_group" "presupuesto" {
  name              = "presupuesto-ehc"
  resource_group_id = azurerm_resource_group.rg.id
  amount            = var.presupuesto_eur
  time_grain        = "Monthly"

  time_period {
    start_date = var.inicio_presupuesto
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    contact_emails = [var.email_alertas]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    contact_emails = [var.email_alertas]
  }
}
