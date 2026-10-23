# Contraseña del administrador local. Se usa solo para entrar con Bastion.
resource "random_password" "admin" {
  length           = 24
  special          = true
  override_special = "!#%*-_=+"
}

resource "azurerm_network_interface" "srv" {
  name                = "nic-srv-ehc-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.etiquetas

  ip_configuration {
    name                          = "interna"
    subnet_id                     = azurerm_subnet.servidores.id
    private_ip_address_allocation = "Dynamic"
    # Sin public_ip_address_id a propósito: la VM no tiene IP pública.
  }
}

# VM pequeña de la cuenta gratuita (B1s: 750 horas/mes para cuentas nuevas).
# Windows Server Core para que quepa bien en 1 GB de RAM.
resource "azurerm_windows_virtual_machine" "srv" {
  name                  = "srv-ehc-01"
  computer_name         = "SRV-EHC-01"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  size                  = "Standard_B1s"
  admin_username        = "adminehc"
  admin_password        = random_password.admin.result
  network_interface_ids = [azurerm_network_interface.srv.id]
  tags                  = local.etiquetas

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-core-g2"
    version   = "latest"
  }
}

# Apagado automático cada noche para no gastar horas de VM.
resource "azurerm_dev_test_global_vm_shutdown_schedule" "apagado" {
  virtual_machine_id    = azurerm_windows_virtual_machine.srv.id
  location              = azurerm_resource_group.rg.location
  enabled               = true
  daily_recurrence_time = var.hora_apagado
  timezone              = "Romance Standard Time"

  notification_settings {
    enabled = false
  }
}
