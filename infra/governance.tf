# Política 1: solo se pueden crear recursos en Spain Central o West Europe.
# Son políticas integradas de Azure, no las invento yo.
resource "azurerm_resource_group_policy_assignment" "regiones_permitidas" {
  name                 = "regiones-permitidas"
  display_name         = "Solo Spain Central y West Europe"
  resource_group_id    = azurerm_resource_group.rg.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"

  parameters = jsonencode({
    listOfAllowedLocations = {
      value = ["spaincentral", "westeurope"]
    }
  })
}

# Política 2: la etiqueta "proyecto" es obligatoria en todo recurso del grupo.
resource "azurerm_resource_group_policy_assignment" "etiqueta_proyecto" {
  name                 = "etiqueta-proyecto-obligatoria"
  display_name         = "Etiqueta 'proyecto' obligatoria"
  resource_group_id    = azurerm_resource_group.rg.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"

  parameters = jsonencode({
    tagName = {
      value = "proyecto"
    }
  })
}
