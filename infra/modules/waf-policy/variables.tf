variable "name" {
  description = "WAF policy name"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "mode" {
  description = "WAF mode: Detection (log only) or Prevention (block)"
  type        = string
  default     = "Prevention"

  validation {
    condition     = contains(["Detection", "Prevention"], var.mode)
    error_message = "mode must be Detection or Prevention."
  }
}

variable "managed_rule_sets" {
  description = "Managed rule sets to enable"
  type = list(object({
    type    = string
    version = string
  }))
  default = [
    { type = "OWASP", version = "3.2" },
    { type = "Microsoft_BotManagerRuleSet", version = "1.0" },
  ]
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
