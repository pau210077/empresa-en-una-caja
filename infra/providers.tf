provider "azurerm" {
  features {}

  # En GitHub Actions la autenticación va por OIDC (ARM_USE_OIDC=true),
  # así que no hay ningún secreto de Azure en el repo.
  storage_use_azuread = true
}

provider "azuread" {}
