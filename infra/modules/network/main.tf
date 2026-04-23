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

  # Legacy optional rule for an Azure Front Door private-link path. This is not
  # part of the SDX mTLS edge design, but is kept while the frontdoor module
  # remains available for non-SDX experiments.
  security_rule {
    name                       = "AllowInboundFromFrontDoor"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureFrontDoor.Backend"
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
      addressPrefix         = local.application_gateway_subnet_cidr
      defaultOutboundAccess = false
      networkSecurityGroup = {
        id = azurerm_network_security_group.application_gateway[0].id
      }
    }
  }
  response_export_values = ["*"]
}


resource "azurerm_network_security_group" "container_apps" {
  count = local.create_subnets_count

  name                = "${var.vnet_resource_group_name}-ca-nsg"
  location            = var.location
  resource_group_name = var.vnet_resource_group_name

  # Container Apps subnet
  # Delegated to Microsoft.App/environments.

  # Allow Container Apps management traffic (required by Azure Container Apps)
  # Allow platform-managed traffic for Container Apps environment.
  # Protocol/ports are '*' because platform requirements vary by feature.
  security_rule {
    name                       = "AllowContainerAppsManagement"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
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
}
# Container Apps subnet for Container Apps Environment
resource "azapi_resource" "container_apps_subnet" {
  count                     = local.create_subnets_count
  type                      = "Microsoft.Network/virtualNetworks/subnets@2023-04-01"
  name                      = var.container_apps_subnet_name
  parent_id                 = data.azurerm_virtual_network.main[0].id
  locks                     = [data.azurerm_virtual_network.main[0].id]
  schema_validation_enabled = false
  body = {
    properties = {
      addressPrefix         = local.container_apps_subnet_cidr
      defaultOutboundAccess = false
      networkSecurityGroup = {
        id = azurerm_network_security_group.container_apps[0].id
      }
      delegations = [
        {
          name = "container-apps-delegation"
          properties = {
            serviceName = "Microsoft.App/environments"
          }
        }
      ]
    }
  }
  response_export_values = ["*"]
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
      # Enable NSG enforcement on private endpoints in this subnet.
      # By default Azure disables network policies for PEs, which would
      # bypass the NSG above. "NetworkSecurityGroupEnabled" applies the
      # NSG to PE traffic without affecting route table behaviour.
      privateEndpointNetworkPolicies = "NetworkSecurityGroupEnabled"
    }
  }
  response_export_values = ["*"]
}
