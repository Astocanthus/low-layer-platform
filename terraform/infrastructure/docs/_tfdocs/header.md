# Terraform - Servers Configurations

[![Terraform](https://img.shields.io/badge/terraform->=1.3.3-blue.svg)](https://www.terraform.io/)
[![Redfish Provider](https://img.shields.io/badge/redfish->=1.6.0-orange.svg)](https://registry.terraform.io/providers/dell/redfish/latest)
[![Vault Provider](https://img.shields.io/badge/vault->=3.20.0-green.svg)](https://registry.terraform.io/providers/hashicorp/vault/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This Terraform provides secure and scalable infrastructure automation for **Dell server configuration** using Redfish API with **HashiCorp Vault integration** for credential management.

## Features

- ✅ **Automated Dell server provisioning** via Redfish protocol
- ✅ **BIOS configuration management** with sequential workflow (disable PXE → RAID → enable PXE)
- ✅ **Secure credential management** through HashiCorp Vault integration
- ✅ **Multi-server fleet deployment** with individual hardware customization
- ✅ **Power management automation** (graceful shutdowns, force restarts)
- ✅ **Asset management integration** with custom tags and naming
- ✅ **Error handling and retry logic** for transient failures
- ✅ **Comprehensive validation** for all configuration parameters

## Prerequisites

### Software Requirements
- **Terraform** >= 1.3.3
- **Terragrunt** >= 0.80 (optional, for enhanced workflow)
- **HashiCorp Vault** cluster with AppRole authentication configured

### Infrastructure Requirements
- **Dell servers** with iDRAC >= 9/Redfish protocol enabled
- **HashiCorp Vault** with the following secrets configured:
  - `secrets/backbone/idrac_root/<server_name>` - iDRAC root credentials (user/password)
  - AppRole authentication method enabled
- **Consul backend** (optional) for remote state management

## Architecture

![Architecture Diagram](./docs/architecture.png)

# Overview

This project use redfish-server module to configure each Dell server with idrac

### **Security Features**
- **Vault Integration**: All credentials stored and retrieved securely from HashiCorp Vault
- **AppRole Authentication**: Automated, secure authentication without human intervention
- **Sensitive Variable Protection**: All passwords and secrets marked as sensitive
- **TLS Configuration**: Production-ready TLS settings for Vault communication

### **Operational Excellence**
- **Error Handling**: Automatic retry for transient failures (network timeouts, API limits)
- **State Management**: Consul backend for team collaboration and state persistence
- **Comprehensive Validation**: Input validation for all parameters with clear error messages

### **Flexibility & Scalability**
- **Multi-Server Support**: Deploy single servers or entire rack fleets
- **Hardware Customization**: Per-server configuration
