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