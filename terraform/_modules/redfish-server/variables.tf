# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# REDFISH SERVER MODULE IMPLEMENTATION
# =============================================================================
# This module encapsulates the complete server configuration workflow
# from initial BIOS setup through RAID configuration to final PXE enablement

# -----------------------------------------------------------------------------
# SERVER CONFIGURATION VARIABLE
# -----------------------------------------------------------------------------
variable "server_config" {
  description = "Redfish connection configuration for the target server with hardware specifications"
  type = object({
    user         = string # Redfish API username
    password     = string # Redfish API password
    endpoint     = string # Redfish API endpoint URL
    ssl_insecure = bool   # SSL certificate validation setting
    server_name  = string # Hostname BIOS server
    asset_tag    = string # Asset tag BIOS configuration (for iPXE customisation)

    hardware = object({
      storage = object({
        controller_id         = string        # RAID controller identifier
        drives                = list(string)  # Physical drive identifiers
        raid_type             = string        # RAID level (RAID0, RAID1, RAID5, etc.)
        volume_name           = string        # Logical volume name
        read_cache_policy     = string        # Read caching strategy
        write_cache_policy    = string        # Write caching strategy  
        disk_cache_policy     = string        # Individual disk cache policy
      })
      
      boot = object({
        boot_order = string # Boot device order configuration
      })
    })
  })

  # Validation for Redfish endpoint URL format
  validation {
    condition     = can(regex("^https://[0-9a-zA-Z.-]+(:([0-9]+))?/?$", var.server_config.endpoint))
    error_message = "Endpoint must be a valid HTTPS URL format (https://hostname:port)."
  }

  # Validation for username - must not be empty
  validation {
    condition     = length(trimspace(var.server_config.user)) > 0
    error_message = "Username cannot be empty or whitespace only."
  }

  # Validation for server_name - must follow DNS hostname conventions
  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9-.]{0,61}[a-zA-Z0-9])?$", var.server_config.server_name))
    error_message = "Server name must be a valid hostname (1-63 chars, alphanumeric and hyphens, cannot start/end with hyphen)."
  }

  # Validation for asset_tag - alphanumeric with limited special characters
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,32}$", var.server_config.asset_tag))
    error_message = "Asset tag must be 1-32 characters containing only alphanumeric characters, underscores, and hyphens."
  }

  # Validation for storage controller ID format
  validation {
    condition     = can(regex("^[A-Za-z0-9.-]+$", var.server_config.hardware.storage.controller_id))
    error_message = "Storage controller ID must contain only alphanumeric characters, dots, and hyphens."
  }

  # Validation for RAID type - must be a supported RAID level
  validation {
    condition = contains([
      "RAID0", "RAID1", "RAID5", "RAID6", "RAID10", "RAID50", "RAID60"
    ], var.server_config.hardware.storage.raid_type)
    error_message = "RAID type must be one of: RAID0, RAID1, RAID5, RAID6, RAID10, RAID50, RAID60."
  }

  # Validation for minimum number of drives based on RAID type
  validation {
    condition = (
      (var.server_config.hardware.storage.raid_type == "RAID0" && length(var.server_config.hardware.storage.drives) >= 1) ||
      (var.server_config.hardware.storage.raid_type == "RAID1" && length(var.server_config.hardware.storage.drives) >= 2) ||
      (var.server_config.hardware.storage.raid_type == "RAID5" && length(var.server_config.hardware.storage.drives) >= 3) ||
      (var.server_config.hardware.storage.raid_type == "RAID6" && length(var.server_config.hardware.storage.drives) >= 4) ||
      (var.server_config.hardware.storage.raid_type == "RAID10" && length(var.server_config.hardware.storage.drives) >= 4 && length(var.server_config.hardware.storage.drives) % 2 == 0) ||
      (contains(["RAID50", "RAID60"], var.server_config.hardware.storage.raid_type) && length(var.server_config.hardware.storage.drives) >= 6)
    )
    error_message = "Number of drives must match RAID type requirements: RAID0(1+), RAID1(2+), RAID5(3+), RAID6(4+), RAID10(4+ even), RAID50/60(6+)."
  }

  # Validation for volume name - must follow naming conventions
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,64}$", var.server_config.hardware.storage.volume_name))
    error_message = "Volume name must be 1-64 characters containing only alphanumeric characters, underscores, and hyphens."
  }

  # Validation for read cache policy
  validation {
    condition = contains([
      "ReadAhead", "AdaptiveReadAhead", "NoReadAhead"
    ], var.server_config.hardware.storage.read_cache_policy)
    error_message = "Read cache policy must be one of: ReadAhead, AdaptiveReadAhead, NoReadAhead."
  }

  # Validation for write cache policy
  validation {
    condition = contains([
      "WriteThrough", "ProtectedWriteBack", "UnprotectedWriteBack"
    ], var.server_config.hardware.storage.write_cache_policy)
    error_message = "Write cache policy must be one of: WriteThrough, ProtectedWriteBack, UnprotectedWriteBack."
  }

  # Validation for disk cache policy
  validation {
    condition = contains([
      "Enabled", "Disabled", "Default"
    ], var.server_config.hardware.storage.disk_cache_policy)
    error_message = "Disk cache policy must be one of: Enabled, Disabled, Default."
  }

  # Validation for boot order format
  validation {
    condition     = length(trimspace(var.server_config.hardware.boot.boot_order)) > 0
    error_message = "Boot order cannot be empty."
  }
}

# -----------------------------------------------------------------------------
# TIMEOUT CONFIGURATION VARIABLE
# -----------------------------------------------------------------------------
variable "timeouts" {
  description = "Operation timeout configuration for server management tasks"
  type = object({
    reset_timeout      = number # Server restart timeout (seconds)
    bios_job_timeout   = number # BIOS configuration job timeout (seconds)
    volume_job_timeout = number # RAID volume creation timeout (seconds)
    power_wait_time    = number # Power management operation timeout (seconds)
  })

  # Default timeout values optimized for enterprise hardware
  default = {
    reset_timeout      = 120   # 2 minutes for server restart
    bios_job_timeout   = 1200  # 20 minutes for BIOS configuration
    volume_job_timeout = 1200  # 20 minutes for RAID volume creation
    power_wait_time    = 120   # 2 minutes for power management
  }

  # Validation for reset timeout - reasonable range
  validation {
    condition     = var.timeouts.reset_timeout >= 30 && var.timeouts.reset_timeout <= 600
    error_message = "Reset timeout must be between 30 and 600 seconds."
  }

  # Validation for BIOS job timeout - reasonable range
  validation {
    condition     = var.timeouts.bios_job_timeout >= 300 && var.timeouts.bios_job_timeout <= 3600
    error_message = "BIOS job timeout must be between 300 and 3600 seconds."
  }

  # Validation for volume job timeout - reasonable range
  validation {
    condition     = var.timeouts.volume_job_timeout >= 300 && var.timeouts.volume_job_timeout <= 7200
    error_message = "Volume job timeout must be between 300 and 7200 seconds."
  }

  # Validation for power wait time - reasonable range
  validation {
    condition     = var.timeouts.power_wait_time >= 30 && var.timeouts.power_wait_time <= 600
    error_message = "Power wait time must be between 30 and 600 seconds."
  }
}