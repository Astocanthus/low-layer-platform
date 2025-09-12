# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# REDFISH SERVER MODULE DEPLOYMENT
# =============================================================================
# Deploy each server using the reusable Redfish server module
# Enables centralized server configuration management with individualized settings

# -----------------------------------------------------------------------------
# MULTI-SERVER MODULE INSTANTIATION
# -----------------------------------------------------------------------------
# Creates a module instance for each server defined in the configuration
# Uses for_each to enable parallel deployment and individual resource management

module "redfish_servers" {
  source = "../_modules/redfish-server"
  server_config = each.value

  # Iterate over server configuration map
  for_each = local.redfish_servers_config
}