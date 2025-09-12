# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# REDFISH SERVER CONFIGURATION RESOURCES
# =============================================================================
# Sequential workflow for complete server provisioning and configuration

# -----------------------------------------------------------------------------
# General settings
# -----------------------------------------------------------------------------

 #Configure general system settings
resource "redfish_dell_system_attributes" "general" {
  redfish_server {
    user         = var.server_config.user
    password     = var.server_config.password
    endpoint     = var.server_config.endpoint
    ssl_insecure = var.server_config.ssl_insecure
  }

  attributes = {
    # FAN configuration
    "ThermalSettings.1.ThermalProfile"            = "Minimum Power"
    "ThermalSettings.1.MinimumFanSpeed"           = 14
  }
}

# -----------------------------------------------------------------------------
# PHASE 1: INITIAL BIOS CONFIGURATION
# -----------------------------------------------------------------------------

#Enable auto update for bios firmware
resource "redfish_dell_lc_attributes" "update_firmware" {
  redfish_server {
    user         = var.server_config.user
    password     = var.server_config.password
    endpoint     = var.server_config.endpoint
    ssl_insecure = var.server_config.ssl_insecure
  }

  // LC attributes to enable auto update
  attributes = {
    "LCAttributes.1.IgnoreCertWarning" = "On"
    "LCAttributes.1.AutoUpdate"        = "Enabled"
  }
}

# Configures BIOS settings with all PXE devices disabled to prevent
# network boot conflicts during RAID configuration
resource "redfish_bios" "bios_disable_default_boot_setting" {
  redfish_server {
    user         = var.server_config.user
    password     = var.server_config.password
    endpoint     = var.server_config.endpoint
    ssl_insecure = var.server_config.ssl_insecure
  }

  # Apply initial BIOS configuration (PXE disabled, boot settings optimized)
  attributes = {
    "PxeDev1EnDis"   = "Disabled"
    "PxeDev2EnDis"   = "Disabled"
    "PxeDev3EnDis"   = "Disabled"
    "PxeDev4EnDis"   = "Disabled"
    "GenericUsbBoot" = "Disabled"
    "HddPlaceholder" = "Enabled"
    "AssetTag"       = var.server_config.asset_tag
    "SysProfile"     = "PerfPerWattOptimizedOs"
    "BootMode"       = "Uefi"
    "BootSeqRetry"   = "Disabled"
  }
  reset_type       = "ForceRestart"
  reset_timeout    = var.timeouts.reset_timeout
  bios_job_timeout = var.timeouts.bios_job_timeout

  # Prevent Terraform from detecting configuration drift on BIOS attributes
  # as they may be modified by other management tools or manual intervention
  lifecycle {
    ignore_changes = [attributes]
  }
  depends_on = [ redfish_dell_lc_attributes.update_firmware ]
}

# -----------------------------------------------------------------------------
# PHASE 2: SYSTEM ATTRIBUTES CONFIGURATION  
# -----------------------------------------------------------------------------
# Configures Dell-specific system attributes such as hostname and asset tags
# This step ensures proper system identification in the infrastructure

resource "redfish_dell_system_attributes" "system_parameters" {
  redfish_server {
    user         = var.server_config.user
    password     = var.server_config.password
    endpoint     = var.server_config.endpoint
    ssl_insecure = var.server_config.ssl_insecure
  }
  
  # Apply system-level configuration
  attributes = {
    "ServerOS.1.HostName"                = var.server_config.server_name
    # "OpenIDConnectServer.1.Name" =
    # "OpenIDConnectServer.1.Enabled" =
    # "OpenIDConnectServer.1.DiscoveryURL" =

  }
  
  # Wait for initial BIOS configuration to complete before setting system attributes
  depends_on = [redfish_bios.bios_disable_default_boot_setting]
}

# -----------------------------------------------------------------------------
# PHASE 3: RAID VOLUME CONFIGURATION
# -----------------------------------------------------------------------------
# Creates and configures the RAID volume for system storage
# Uses optimized settings for performance and reliability

resource "redfish_storage_volume" "volume" {
  redfish_server {
    user         = var.server_config.user
    password     = var.server_config.password
    endpoint     = var.server_config.endpoint
    ssl_insecure = var.server_config.ssl_insecure
  }

  # RAID controller and volume configuration
  storage_controller_id = var.server_config.hardware.storage.controller_id
  volume_name           = var.server_config.hardware.storage.volume_name
  raid_type             = var.server_config.hardware.storage.raid_type
  drives                = var.server_config.hardware.storage.drives
  
  # Apply RAID configuration on next system reset
  settings_apply_time   = "OnReset"
  reset_type            = "PowerCycle"          # Full power cycle for RAID initialization
  reset_timeout         = var.timeouts.reset_timeout
  volume_job_timeout    = var.timeouts.volume_job_timeout
  
  # Performance optimization settings
  optimum_io_size_bytes = 131072                 # 128KB optimal I/O size
  read_cache_policy     = "AdaptiveReadAhead"    # Adaptive read caching
  write_cache_policy    = "UnprotectedWriteBack" # Write-back caching for performance
  disk_cache_policy     = "Disabled"             # Disable individual disk caching

  # Prevent Terraform from detecting configuration drift on hardware-dependent attributes
  lifecycle {
    ignore_changes = [
      capacity_bytes, # Capacity determined by physical drives
      raid_type,      # RAID type may be normalized by controller
      system_id,      # System ID assigned by hardware
      volume_type,    # Legacy type to manage to not trigger update on apply 
      drives          # Drive list may be reordered by controller
    ]
  }

  # Wait for system attributes configuration before creating RAID volume
  depends_on = [redfish_dell_system_attributes.system_parameters]
}

# -----------------------------------------------------------------------------
# PHASE 4: SYSTEM RESTART AFTER RAID CONFIGURATION
# -----------------------------------------------------------------------------
# Performs graceful shutdown after RAID configuration to ensure all
# storage changes are properly committed and initialized

resource "redfish_power" "system_restart_after_raid" {
  redfish_server {
    user         = var.server_config.user
    password     = var.server_config.password
    endpoint     = var.server_config.endpoint
    ssl_insecure = var.server_config.ssl_insecure
  }

  # Graceful shutdown ensures data integrity and proper RAID initialization
  desired_power_action = "GracefulShutdown"
  maximum_wait_time    = var.timeouts.power_wait_time
  
  # Wait for RAID volume configuration to complete
  depends_on = [redfish_storage_volume.volume]
}

# -----------------------------------------------------------------------------
# PHASE 5: FINAL BIOS CONFIGURATION WITH PXE ENABLEMENT
# -----------------------------------------------------------------------------
# Applies final BIOS configuration with PXE enabled on the management NIC
# and sets proper boot order for OS provisioning

resource "redfish_bios" "bios_enable_pxe" {
  redfish_server {
    user         = var.server_config.user
    password     = var.server_config.password
    endpoint     = var.server_config.endpoint
    ssl_insecure = var.server_config.ssl_insecure
  }

  # Apply final BIOS configuration with PXE enabled and boot order set
  attributes = {
    "PxeDev1EnDis"   = "Enabled"
    "SetBootOrderEn" = var.server_config.hardware.boot.boot_order
  }
  reset_type       = "PowerCycle"
  reset_timeout    = var.timeouts.reset_timeout
  bios_job_timeout = var.timeouts.bios_job_timeout

  lifecycle {
    ignore_changes = [attributes]
  }
  depends_on = [redfish_power.system_restart_after_raid]
}