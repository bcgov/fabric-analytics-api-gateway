locals {
  create_container_apps_count = var.enable_container_apps ? 1 : 0
  create_front_door_count     = var.enable_front_door ? 1 : 0
  create_monitoring_count     = var.enable_monitoring ? 1 : 0
  create_network_count        = var.enable_network ? 1 : 0
  create_resource_group_count = var.create_resource_group ? 1 : 0

  normalized_app_name = lower(replace(var.app_name, "_", "-"))
  normalized_env      = lower(var.app_env)
  name_prefix         = "${local.normalized_app_name}-${local.normalized_env}"

  resource_group_name = var.resource_group_name != null && trimspace(var.resource_group_name) != "" ? var.resource_group_name : "${local.name_prefix}-rg"

  common_tags = merge(
    {
      app         = var.app_name
      environment = var.app_env
      managed_by  = "Terraform"
      repository  = var.repo_name
    },
    var.tags,
  )
}
