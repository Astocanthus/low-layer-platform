# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# MODULE OUTPUTS
# =============================================================================
# Provides resource identifiers for dependency management

output "bios_config_id" {
  description = "Resource ID of the final BIOS configuration"
  value       = redfish_bios.bios_enable_pxe.id
}

output "volume_id" {
  description = "Resource ID of the created RAID volume"
  value       = redfish_storage_volume.volume.id
}