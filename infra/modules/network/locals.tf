locals {
  create_subnets_count = var.enabled && var.vnet_name != null && trimspace(var.vnet_name) != "" && var.vnet_resource_group_name != null && trimspace(var.vnet_resource_group_name) != "" ? 1 : 0
  # Acquire address space from Azure
  vnet_address_space = data.azurerm_virtual_network.main[0].address_space[0]

  base_ip      = "${local.octets[0]}.${local.octets[1]}.${local.octets[2]}"
  octets       = split(".", local.vnet_ip_base)
  vnet_ip_base = split("/", local.vnet_address_space)[0]


  private_endpoints_subnet_cidr   = "${local.base_ip}.0/27"  # 32 addresses, 5 reserved by Azure, 27 usable
  container_apps_subnet_cidr      = "${local.base_ip}.32/26" # 64 addresses, 5 reserved by Azure, 59 usable
  application_gateway_subnet_cidr = "${local.base_ip}.96/28" # 16 addresses, 5 reserved by Azure, 11 usable
}
