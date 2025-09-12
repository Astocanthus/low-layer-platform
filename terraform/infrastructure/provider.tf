# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# MAIN TERRAFORM CONFIGURATION - REDFISH SERVER DEPLOYMENT
# =============================================================================
# This file orchestrates the deployment of multiple servers using the
# Redfish server module with comprehensive server fleet management

# -----------------------------------------------------------------------------
# TERRAFORM REQUIREMENTS
# -----------------------------------------------------------------------------
# Defines minimum versions and required providers for consistent deployments
# across different environments and team members

terraform {
  required_version = ">=1.3.3"
  required_providers {
    redfish = {
      version = ">=1.6.0"
      source  = "registry.terraform.io/dell/redfish" # Official Dell provider
    }
  }
}

# -----------------------------------------------------------------------------
# AUTHENTICATION VARIABLES
# -----------------------------------------------------------------------------
# AppRole authentication provides secure, automated authentication to Vault
# without requiring human interaction or long-lived credentials

variable "login_approle_role_id" {
  description = "Vault AppRole Role ID for automated authentication"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.login_approle_role_id) > 0
    error_message = "AppRole Role ID cannot be empty."
  }
}

variable "login_approle_secret_id" {
  description = "Vault AppRole Secret ID (rotate regularly)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.login_approle_secret_id) > 0
    error_message = "AppRole Secret ID cannot be empty."
  }
}

# -----------------------------------------------------------------------------
# HASHICORP VAULT PROVIDER CONFIGURATION
# -----------------------------------------------------------------------------
# Configures connection to Vault for centralized secrets management
# Uses AppRole authentication for secure, automated access

provider "vault" {
  address         = "https://vault.internal"
  skip_tls_verify = false

  # AppRole authentication for automated access
  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = var.login_approle_role_id
      secret_id = var.login_approle_secret_id
    }
  }
}

# -----------------------------------------------------------------------------
# VAULT DATAS
# -----------------------------------------------------------------------------

# Retrieve iDRAC root credentials from Vault secrets engine
data "vault_generic_secret" "idrac_credentials" {
  path     = "secrets/backbone/idrac_root/${each.value.server_name}"
  for_each = var.servers
}

# Merges server configuration with credentials retrieved from Vault
# This approach separates infrastructure config from sensitive credentials
locals {
  redfish_servers_config = {
    for server_name, server_config in var.servers : server_name => merge(
      server_config,
      {
        user     = data.vault_generic_secret.idrac_credentials[server_name].data["user"]
        password = data.vault_generic_secret.idrac_credentials[server_name].data["password"]
      }
    )
  }
}

# -----------------------------------------------------------------------------
# DELL REDFISH PROVIDER CONFIGURATION
# -----------------------------------------------------------------------------
# Configures the Redfish provider for server hardware management
# Uses server credential mapping for multi-server deployments

provider "redfish" {
  # Server credential mapping configuration
  # `redfish_servers` provides centralized credential management for multiple BMCs
  # This approach enhances security by centralizing password management
  # and enables the use of `redfish_alias` in resources for cleaner configuration
  
  # Map structure expected:
  # {
  #   "server" = {
  #     user     = "username"
  #     password = "password"  
  #     endpoint = "https://bmc.example.com"
  #     ssl_insecure = true/false
  #   }
  # }
}

# =============================================================================
# SECURITY NOTES
# =============================================================================
# 
# Production Checklist:
# - Use environment variables for credentials:
#   export VAULT_ROLE_ID="your-role-id"
#   export VAULT_SECRET_ID="your-secret-id"