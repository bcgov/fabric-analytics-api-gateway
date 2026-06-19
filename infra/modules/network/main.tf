data "azurerm_virtual_network" "main" {
  count               = local.create_subnets_count
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group_name
}

resource "azurerm_network_security_group" "application_gateway" {
  count = local.create_subnets_count

  name                = "${var.resource_group_name}-agw-nsg"
  location            = var.location
  resource_group_name = var.vnet_resource_group_name

  security_rule {
    name                       = "AllowHttpsInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = local.application_gateway_subnet_cidr
  }

  security_rule {
    name                       = "AllowGatewayManagerInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAzureLoadBalancerInbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowInternetOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  tags = var.common_tags
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_network_security_group" "privateendpoints" {
  count = local.create_subnets_count

  name                = "${var.resource_group_name}-pe-nsg"
  location            = var.location
  resource_group_name = var.vnet_resource_group_name

  # --- Inbound: from the VNet (e.g. App Gateway subnet) to reach private endpoints ---
  security_rule {
    name                       = "AllowVnetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "1433"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = local.private_endpoints_subnet_cidr
  }

  # --- Outbound: Internet (external OAuth, APIM developer portal, etc.) ---
  security_rule {
    name                       = "AllowInternetOutbound"
    priority                   = 140
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "1433"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Internet"
  }

  tags = var.common_tags
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azapi_resource" "application_gateway_subnet" {
  count                     = local.create_subnets_count
  type                      = "Microsoft.Network/virtualNetworks/subnets@2023-04-01"
  name                      = var.application_gateway_subnet_name
  parent_id                 = data.azurerm_virtual_network.main[0].id
  locks                     = [data.azurerm_virtual_network.main[0].id]
  schema_validation_enabled = false
  body = {
    properties = {
      addressPrefix = local.application_gateway_subnet_cidr

      networkSecurityGroup = {
        id = azurerm_network_security_group.application_gateway[0].id
      }
    }
  }
  response_export_values = ["*"]
}

resource "azurerm_network_security_group" "apim" {
  count = local.create_subnets_count

  name                = "${var.resource_group_name}-apim-nsg"
  location            = var.location
  resource_group_name = var.vnet_resource_group_name

  # Inbound: management plane — required for APIM StandardV2 in External VNet mode
  security_rule {
    name                       = "AllowApiManagementInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3443"
    source_address_prefix      = "ApiManagement"
    destination_address_prefix = local.apim_subnet_cidr
  }

  # Inbound: client traffic (External mode — inbound from internet to gateway)
  security_rule {
    name                       = "AllowHttpsInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = local.apim_subnet_cidr
  }

  # Inbound: Azure Load Balancer health probes
  security_rule {
    name                       = "AllowAzureLoadBalancerInbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Outbound: HTTPS to Storage, Key Vault, OAuth (Azure services + internet)
  security_rule {
    name                       = "AllowHttpsOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = local.apim_subnet_cidr
    destination_address_prefix = "*"
  }

  # Outbound: Azure SQL (APIM developer portal config, analytics)
  security_rule {
    name                       = "AllowSqlOutbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = local.apim_subnet_cidr
    destination_address_prefix = "Sql"
  }

  # Outbound: AMQP to Event Hub (diagnostic log streaming)
  security_rule {
    name                       = "AllowEventHubOutbound"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["5671", "5672"]
    source_address_prefix      = local.apim_subnet_cidr
    destination_address_prefix = "EventHub"
  }

  tags = var.common_tags
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azapi_resource" "apim_subnet" {
  count                     = local.create_subnets_count
  type                      = "Microsoft.Network/virtualNetworks/subnets@2023-04-01"
  name                      = var.apim_subnet_name
  parent_id                 = data.azurerm_virtual_network.main[0].id
  locks                     = [data.azurerm_virtual_network.main[0].id]
  schema_validation_enabled = false
  body = {
    properties = {
      addressPrefix = local.apim_subnet_cidr
      networkSecurityGroup = {
        id = azurerm_network_security_group.apim[0].id
      }
      # APIM StandardV2/PremiumV2 VNet integration requires delegation to Microsoft.Web/serverFarms
      delegations = [
        {
          name = "Microsoft.Web.serverFarms"
          properties = {
            serviceName = "Microsoft.Web/serverFarms"
          }
        }
      ]
    }
  }
  response_export_values = ["*"]

  depends_on = [azapi_resource.privateendpoints_subnet]
}

resource "azapi_resource" "privateendpoints_subnet" {
  count                     = local.create_subnets_count
  type                      = "Microsoft.Network/virtualNetworks/subnets@2023-04-01"
  name                      = var.private_endpoint_subnet_name
  parent_id                 = data.azurerm_virtual_network.main[0].id
  locks                     = [data.azurerm_virtual_network.main[0].id]
  schema_validation_enabled = false
  body = {
    properties = {
      addressPrefix         = local.private_endpoints_subnet_cidr
      defaultOutboundAccess = false
      networkSecurityGroup = {
        id = azurerm_network_security_group.privateendpoints[0].id
      }
    }
  }
  response_export_values = ["*"]
}
