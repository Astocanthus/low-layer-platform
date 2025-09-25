# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# MAIN TERRAFORM CONFIGURATION - KUBERNETES & INFRASTRUCTURE DEPLOYMENT
# =============================================================================
# This file orchestrates the deployment of Kubernetes infrastructure,
# Helm charts, and Unifi network management with comprehensive
# multi-provider orchestration

# -----------------------------------------------------------------------------
# TERRAFORM REQUIREMENTS
# -----------------------------------------------------------------------------
# Defines minimum versions and required providers for consistent deployments
# across different environments and team members

terraform {
  required_version = ">=1.3.3"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.16.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.8.0"
    }
    unifi = {
      source  = "ubiquiti-community/unifi"
      version = "0.41.3"
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
# VAULT DATA SOURCES
# -----------------------------------------------------------------------------
# Retrieves credentials and tokens from Vault for various services
# This approach separates infrastructure config from sensitive credentials

# Retrieve OIDC token for Kubernetes authentication
data "vault_generic_secret" "oidc_token" {
  path = "identity/oidc/token/kubernetes-low-layer-oidc-token"
}

# Retrieve Unifi controller API credentials
data "vault_generic_secret" "unifi_credentials" {
  path = "secrets/backbone/unifi/terraform_api"
}

# Retrieve Synology API credentials
data "vault_generic_secret" "synology_credentials" {
  path = "secrets/backbone/synology/kubernetes"
}

# -----------------------------------------------------------------------------
# KUBERNETES PROVIDER CONFIGURATION
# -----------------------------------------------------------------------------
# Configures Kubernetes provider using OIDC token from Vault
# Enables secure, token-based authentication to Kubernetes API

provider "kubernetes" {
  host      = "https://kube.low-layer.internal"
  token     = data.vault_generic_secret.oidc_token.data["token"]
  insecure  = false
}

# -----------------------------------------------------------------------------
# KUBECTL PROVIDER CONFIGURATION
# -----------------------------------------------------------------------------
# Configures kubectl provider for advanced Kubernetes operations
# Uses same authentication as kubernetes provider for consistency

provider "kubectl" {
  host             = "https://kube.low-layer.internal"
  token            = data.vault_generic_secret.oidc_token.data["token"]
  load_config_file = false # Security: disable config file loading
  insecure         = false
}

# -----------------------------------------------------------------------------
# HELM PROVIDER CONFIGURATION
# -----------------------------------------------------------------------------
# Configures Helm provider for Kubernetes package management
# Inherits authentication from Kubernetes provider configuration

provider "helm" {
  kubernetes {
    host     = "https://kube.low-layer.internal"
    token    = data.vault_generic_secret.oidc_token.data["token"]
    insecure = false
  }
}

# -----------------------------------------------------------------------------
# UNIFI PROVIDER CONFIGURATION
# -----------------------------------------------------------------------------
# Configures Unifi provider for network infrastructure management
# Uses API key authentication retrieved from Vault

provider "unifi" {
  api_url        = "https://unifi.internal"
  api_key        = data.vault_generic_secret.unifi_credentials.data["api_key"]
  allow_insecure = false
}

# =============================================================================
# USAGE NOTES
# =============================================================================
# 
# Use environment variables for credentials:
# export VAULT_ROLE_ID="your-role-id"
# export VAULT_SECRET_ID="your-secret-id"