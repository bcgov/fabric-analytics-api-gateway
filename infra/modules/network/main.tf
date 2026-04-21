data "azurerm_virtual_network" "main" {
  count               = local.create_subnets_count
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group_name
}

resource "azurerm_network_security_group" "privateendpoints" {
  count = local.create_subnets_count

  name                = "${var.resource_group_name}-pe-nsg"
  location            = var.location
  resource_group_name = var.vnet_resource_group_name

  # Allow Inbound from Azure Front Door backends through Private Link to private
  # endpoints in this subnet on 443. Provider requires source/destination prefixes.
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


  tags = var.common_tags
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
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
    destination_address_prefix = local.container_apps_subnet_cidr
    source_port_range          = "*"
    destination_port_range     = "*"
  }
}
# Container Apps subnet for Container Apps Environment
resource "azapi_resource" "container_apps_subnet" {
  count     = local.create_subnets_count
  type      = "Microsoft.Network/virtualNetworks/subnets@2023-04-01"
  name      = var.container_apps_subnet_name
  parent_id = data.azurerm_virtual_network.main[0].id
  locks     = [data.azurerm_virtual_network.main[0].id]
  body = {
    properties = {
      addressPrefix = local.container_apps_subnet_cidr
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
  count     = local.create_subnets_count
  type      = "Microsoft.Network/virtualNetworks/subnets@2023-04-01"
  name      = var.private_endpoint_subnet_name
  parent_id = data.azurerm_virtual_network.main[0].id
  locks     = [data.azurerm_virtual_network.main[0].id]
  body = {
    properties = {
      addressPrefix = local.private_endpoints_subnet_cidr
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
