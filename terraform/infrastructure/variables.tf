# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# SERVER FLEET CONFIGURATION
# =============================================================================
# Configuration for the server fleet deployment with specific hardware configs

# -----------------------------------------------------------------------------
# SERVER FLEET VARIABLE
# -----------------------------------------------------------------------------
variable "servers" {
  description = "Map of server configurations for the complete rack deployment"
  type = map(object({
    endpoint     = string
    ssl_insecure = bool
    server_name  = string
    asset_tag    = string

    hardware = object({
      storage = object({
        controller_id         = string
        drives                = list(string)
        raid_type             = string
        volume_name           = string
        read_cache_policy     = string
        write_cache_policy    = string
        disk_cache_policy     = string
      })
      
      boot = object({
        boot_order = string
      })
    })
  }))

  # Validation for unique server endpoints
  validation {
    condition = length(values(var.servers)[*].endpoint) == length(distinct(values(var.servers)[*].endpoint))
    error_message = "All server endpoints must be unique across the fleet."
  }

  # Validation for unique server names
  validation {
    condition = length(values(var.servers)[*].server_name) == length(distinct(values(var.servers)[*].server_name))
    error_message = "All server names must be unique across the fleet."
  }
}