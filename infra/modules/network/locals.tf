locals {
  create_subnets_count = var.enabled && var.vnet_name != null && trimspace(var.vnet_name) != "" && var.vnet_resource_group_name != null && trimspace(var.vnet_resource_group_name) != "" ? 1 : 0

  # Acquire address space from Azure. The data source has count 0 when the module
  # is disabled, so guard the [0] index with the same count — indexing a 0-length
  # list would otherwise error at plan time even when no subnets are created.
  # The placeholder is only ever consumed by resources that are themselves gated
  # on create_subnets_count, so it never reaches a real resource.
  vnet_address_space = local.create_subnets_count > 0 ? data.azurerm_virtual_network.main[0].address_space[0] : "0.0.0.0/0"

  base_ip      = "${local.octets[0]}.${local.octets[1]}.${local.octets[2]}"
  octets       = split(".", local.vnet_ip_base)
  vnet_ip_base = split("/", local.vnet_address_space)[0]

  private_endpoints_subnet_cidr   = "${local.base_ip}.0/27"  # .0-.31   — 32 addresses, 5 reserved by Azure
  apim_subnet_cidr                = "${local.base_ip}.32/27" # .32-.63  — APIM StandardV2 VNet injection (/27 min)
  application_gateway_subnet_cidr = "${local.base_ip}.96/27" # .96-.127 — App Gateway v2 requires a /27 minimum
}
