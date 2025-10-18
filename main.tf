# Define variables
variable "rgname" {
  default = "Java-Reac-Project"
}

variable "location" {
  default = "West Us"
}

variable "ssh_key" {
  default = "ssh-key"
}
# Provider configuration
provider "azurerm" {
  features {}
  subscription_id = "4733385e-ac73-405b-8349-e777e3a42950"
}

# Create a resource group
resource "azurerm_resource_group" "example" {
  name     = var.rgname
  location = var.location
}

resource "azurerm_ssh_public_key" "sshkey1" {
  name                = var.ssh_key
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  public_key          = file("~/.ssh/id_rsa.pub")
}

# Create a virtual network
resource "azurerm_virtual_network" "example" {
  name                = "projVnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

# Create a subnet
resource "azurerm_subnet" "example" {
  name                 = "projSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
}
# ----- create public IP----
resource "azurerm_public_ip" "public_ip" {
  name                = "pip-proj"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  allocation_method   = "Static"
}

# Create a network interface
resource "azurerm_network_interface" "example" {
  name                = "projNIC"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id # Associate public ip to NIC - Association
  }
}
resource "azurerm_network_security_group" "nsg_name1" {
  name                = "projnsg"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  security_rule {
    name                       = "project"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
# ---- NIC and NSG Association ------

resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.example.id
  network_security_group_id = azurerm_network_security_group.nsg_name1.id
}

# Create a Virtual Machine
resource "azurerm_linux_virtual_machine" "example" {
  name                  = "ProjectVM"
  resource_group_name   = azurerm_resource_group.example.name
  location              = azurerm_resource_group.example.location
  size                  = "Standard_B2s"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.example.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = azurerm_ssh_public_key.sshkey1.public_key
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}