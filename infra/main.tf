locals {
  etiquetas = {
    proyecto    = var.proyecto
    entorno     = var.entorno
    propietario = var.propietario
    empresa     = var.empresa
  }
}

resource "random_string" "sufijo" {
  length  = 6
  upper   = false
  special = false
}

# Grupo de recursos: contenedor de todo el proyecto. Con esto se borra todo de golpe.
resource "azurerm_resource_group" "rg" {
  name     = "rg-empresa-caja-${var.entorno}"
  location = var.ubicacion
  tags     = local.etiquetas
}
