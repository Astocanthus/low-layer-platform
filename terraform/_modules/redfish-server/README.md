<!-- BEGIN_TF_DOCS -->
# Terraform module - Redfish Server Configuration

[![Terraform](https://img.shields.io/badge/terraform->=1.3.3-blue.svg)](https://www.terraform.io/)
[![Redfish Provider](https://img.shields.io/badge/redfish->=1.6.0-orange.svg)](https://registry.terraform.io/providers/dell/redfish/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This Terraform provides secure and scalable infrastructure automation for **Dell server configuration** using Redfish API.

## Features

- ✅ **Automated Dell server provisioning** via Redfish protocol
- ✅ **BIOS configuration management** with sequential workflow (disable PXE → RAID → enable PXE)
- ✅ **Power management automation** (graceful shutdowns, force restarts)
- ✅ **Asset management integration** with custom tags and naming
- ✅ **Comprehensive validation** for all configuration parameters
- ✅ **Modular architecture** for reusability across environments

## Prerequisites

### Software Requirements
- **Terraform** >= 1.3.3

### Infrastructure Requirements
- **Dell servers** with iDRAC >= 9/Redfish protocol enabled

# Overview

This module automates the complete lifecycle of Dell server provisioning using industry best practices:

### **Sequential Workflow**
1. **Phase 1**: Initial BIOS configuration (PXE disabled to prevent boot conflicts)
2. **Phase 2**: System attributes setup (hostname, asset tags)
3. **Phase 3**: RAID volume creation with performance optimization
4. **Phase 4**: Graceful system restart for RAID initialization
5. **Phase 5**: Final BIOS configuration (PXE enabled for OS provisioning)

### **Flexibility & Scalability**
- **Hardware Customization**: Per-server RAID, BIOS, and boot configuration
- **Modular Design**: Reusable components for different deployment scenarios
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.3.3 |
| <a name="requirement_redfish"></a> [redfish](#requirement\_redfish) | >=1.6.0 |
## Providers

| Name | Version |
|------|---------|
| <a name="provider_redfish"></a> [redfish](#provider\_redfish) | >=1.6.0 |
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_server_config"></a> [server\_config](#input\_server\_config) | Redfish connection configuration for the target server with hardware specifications | <pre>object({<br/>    user         = string # Redfish API username<br/>    password     = string # Redfish API password<br/>    endpoint     = string # Redfish API endpoint URL<br/>    ssl_insecure = bool   # SSL certificate validation setting<br/>    server_name  = string # Hostname BIOS server<br/>    asset_tag    = string # Asset tag BIOS configuration (for iPXE customisation)<br/><br/>    hardware = object({<br/>      storage = object({<br/>        controller_id         = string        # RAID controller identifier<br/>        drives                = list(string)  # Physical drive identifiers<br/>        raid_type             = string        # RAID level (RAID0, RAID1, RAID5, etc.)<br/>        volume_name           = string        # Logical volume name<br/>        read_cache_policy     = string        # Read caching strategy<br/>        write_cache_policy    = string        # Write caching strategy  <br/>        disk_cache_policy     = string        # Individual disk cache policy<br/>      })<br/>      <br/>      boot = object({<br/>        boot_order = string # Boot device order configuration<br/>      })<br/>    })<br/>  })</pre> | n/a | yes |
| <a name="input_timeouts"></a> [timeouts](#input\_timeouts) | Operation timeout configuration for server management tasks | <pre>object({<br/>    reset_timeout      = number # Server restart timeout (seconds)<br/>    bios_job_timeout   = number # BIOS configuration job timeout (seconds)<br/>    volume_job_timeout = number # RAID volume creation timeout (seconds)<br/>    power_wait_time    = number # Power management operation timeout (seconds)<br/>  })</pre> | <pre>{<br/>  "bios_job_timeout": 1200,<br/>  "power_wait_time": 120,<br/>  "reset_timeout": 120,<br/>  "volume_job_timeout": 1200<br/>}</pre> | no |
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bios_config_id"></a> [bios\_config\_id](#output\_bios\_config\_id) | Resource ID of the final BIOS configuration |
| <a name="output_volume_id"></a> [volume\_id](#output\_volume\_id) | Resource ID of the created RAID volume |

## Roadmap

- [ ] Enhanced configurations options

## Support

Need help? Here's how to get support:

1. 📖 Check the [complete documentation](./docs/)
2. 🐛 Report bugs by opening an [issue](https://github.com/Astocanthus/low-layer-platform/issues)

## Authors

Maintained by [Astocanthus](https://github.com/Astocanthus) with ❤️

## Changelog

See [CHANGELOG.md](./CHANGELOG.md) for detailed version history and breaking changes.

---
**Note**: This module is actively maintained. For questions about enterprise support or custom implementations, please contact us at [support@your-org.com](mailto:contact@low-layer.com).
<!-- END_TF_DOCS -->