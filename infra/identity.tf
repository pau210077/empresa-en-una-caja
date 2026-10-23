# Un grupo de Entra ID por departamento.
resource "azuread_group" "contabilidad" {
  display_name     = "gg-ehc-contabilidad"
  description      = "Contabilidad de Gestoría Hortensia Demo (proyecto de prueba)"
  security_enabled = true
}

resource "azuread_group" "laboral" {
  display_name     = "gg-ehc-laboral"
  description      = "Laboral de Gestoría Hortensia Demo (proyecto de prueba)"
  security_enabled = true
}

resource "azuread_group" "direccion" {
  display_name     = "gg-ehc-direccion"
  description      = "Dirección de Gestoría Hortensia Demo (proyecto de prueba)"
  security_enabled = true
}

# Usuarios de prueba, uno por departamento. Son ficticios y solo existen en este tenant.
resource "random_password" "usuario" {
  for_each         = toset(["ana.ruiz", "marc.puig", "laura.vidal"])
  length           = 24
  special          = true
  override_special = "!#%*-_=+"
}

resource "azuread_user" "ana" {
  user_principal_name   = "ana.ruiz@${data.azuread_domains.dominios.domains[0].domain_name}"
  display_name          = "Ana Ruiz (Contabilidad)"
  mail_nickname         = "ana.ruiz"
  password              = random_password.usuario["ana.ruiz"].result
  force_password_change = true
}

resource "azuread_user" "marc" {
  user_principal_name   = "marc.puig@${data.azuread_domains.dominios.domains[0].domain_name}"
  display_name          = "Marc Puig (Laboral)"
  mail_nickname         = "marc.puig"
  password              = random_password.usuario["marc.puig"].result
  force_password_change = true
}

resource "azuread_user" "laura" {
  user_principal_name   = "laura.vidal@${data.azuread_domains.dominios.domains[0].domain_name}"
  display_name          = "Laura Vidal (Dirección)"
  mail_nickname         = "laura.vidal"
  password              = random_password.usuario["laura.vidal"].result
  force_password_change = true
}

resource "azuread_group_member" "ana" {
  group_object_id  = azuread_group.contabilidad.object_id
  member_object_id = azuread_user.ana.object_id
}

resource "azuread_group_member" "marc" {
  group_object_id  = azuread_group.laboral.object_id
  member_object_id = azuread_user.marc.object_id
}

resource "azuread_group_member" "laura" {
  group_object_id  = azuread_group.direccion.object_id
  member_object_id = azuread_user.laura.object_id
}
