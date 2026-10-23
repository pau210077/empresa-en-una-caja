# Red virtual con dos subredes. La VM no tiene IP pública: solo se llega a ella por la red interna.
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-ehc-${var.entorno}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.10.0.0/16"]
  tags                = local.etiquetas
}

# Subred de servidores: aquí vive la VM.
resource "azurerm_subnet" "servidores" {
  name                 = "snet-servidores"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

# Subred de gestión: reservada para herramientas de administración futuras.
resource "azurerm_subnet" "gestion" {
  name                 = "snet-gestion"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.2.0/24"]
}

# NSG con solo dos reglas: RDP desde dentro de la red (Bastion) y cerrar la entrada desde Internet.
resource "azurerm_network_security_group" "servidores" {
  name                = "nsg-servidores"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.etiquetas

  security_rule {
    name                       = "permitir-rdp-desde-red-virtual"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "denegar-entrada-internet"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "servidores" {
  subnet_id                 = azurerm_subnet.servidores.id
  network_security_group_id = azurerm_network_security_group.servidores.id
}

# Azure Bastion en modo Developer: gratis, no necesita AzureBastionSubnet ni IP pública.
# Limitación de Microsoft: una sola conexión a la vez y sin peering.
resource "azurerm_bastion_host" "bastion" {
  name                = "bastion-ehc-${var.entorno}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Developer"
  virtual_network_id  = azurerm_virtual_network.vnet.id
  tags                = local.etiquetas
}
