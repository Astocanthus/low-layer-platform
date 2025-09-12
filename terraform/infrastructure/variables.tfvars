# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# TERRAFORM VARIABLES CONFIGURATION
# =============================================================================
# Configuration for OpenStack rack deployment

# -----------------------------------------------------------------------------
# SERVER FLEET CONFIGURATION
# -----------------------------------------------------------------------------
servers = {
  "ctl0" = {
    endpoint     = "https://192.168.0.200"
    ssl_insecure = true
    asset_tag    = "OpenstackController"
    server_name   = "ctrl0-low-layer"
    hardware     = {
      storage = {
        controller_id         = "RAID.Integrated.1-1"
        drives                = ["Physical Disk 0:1:0", "Physical Disk 0:1:1"]
        raid_type             = "RAID1"
        volume_name           = "SystemVolume"
        read_cache_policy     = "AdaptiveReadAhead"
        write_cache_policy    = "UnprotectedWriteBack"
        disk_cache_policy     = "Disabled"
      }
      boot = {
        boot_order = "RAID.Integrated.1-1,NIC.PxeDevice.1-1"
      }
    } 
  },
  "srv0" = {
    endpoint     = "https://192.168.0.210"
    ssl_insecure = true
    asset_tag    = "OpenstackComputer"
    server_name   = "srv0-low-layer"
    hardware     = {
      storage = {
        controller_id         = "RAID.Integrated.1-1"
        drives                = ["Physical Disk 0:1:0", "Physical Disk 0:1:1"]
        raid_type             = "RAID1"
        volume_name           = "SystemVolume"
        read_cache_policy     = "AdaptiveReadAhead"
        write_cache_policy    = "UnprotectedWriteBack"
        disk_cache_policy     = "Disabled"
      }
      boot = {
        boot_order = "RAID.Integrated.1-1,NIC.PxeDevice.1-1"
      }
    } 
  },
  "srv1" = {
    endpoint     = "https://192.168.0.211"
    ssl_insecure = true
    asset_tag    = "OpenstackComputer"
    server_name   = "srv1-low-layer"
    hardware     = {
      storage = {
        controller_id         = "RAID.Integrated.1-1"
        drives                = ["Physical Disk 0:1:0", "Physical Disk 0:1:1"]
        raid_type             = "RAID1"
        volume_name           = "SystemVolume"
        read_cache_policy     = "AdaptiveReadAhead"
        write_cache_policy    = "UnprotectedWriteBack"
        disk_cache_policy     = "Disabled"
      }
      boot = {
        boot_order = "RAID.Integrated.1-1,NIC.PxeDevice.1-1"
      }
    } 
  }
}