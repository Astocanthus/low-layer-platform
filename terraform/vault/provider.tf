# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# VAULT PROVIDER CONFIGURATION - SECRETS MANAGEMENT
# =============================================================================
# This file configures HashiCorp Vault provider for centralized secrets
# management with AppRole authentication for secure service-to-service access

# -----------------------------------------------------------------------------
# TERRAFORM REQUIREMENTS
# -----------------------------------------------------------------------------
# Defines minimum versions and required providers for consistent deployments
# across different environments and team members

terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.1.0"
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


# =============================================================================
# SECURITY NOTES
# =============================================================================
# 
# Production Checklist:
# - Use environment variables for credentials:
#   export VAULT_ROLE_ID="your-role-id"
#   export VAULT_SECRET_ID="your-secret-id"