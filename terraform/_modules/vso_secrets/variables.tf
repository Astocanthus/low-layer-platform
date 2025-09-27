# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# VAULT STATIC SECRETS MANAGEMENT VARIABLES
# =============================================================================
# This file defines the variables required for static secret management
# through Vault Secret Operator (VSO) in a Kubernetes cluster

# -----------------------------------------------------------------------------
# KUBERNETES CONFIGURATION
# -----------------------------------------------------------------------------

variable "namespace" {
  description = "Kubernetes namespace where to deploy Vault connection resources"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace))
    error_message = "Namespace must follow Kubernetes naming conventions."
  }
}

# -----------------------------------------------------------------------------
# VAULT AUTHENTICATION CONFIGURATION
# -----------------------------------------------------------------------------

variable "audience" {
  description = "JWT audience allowed for Kubernetes token authentication with Vault"
  type        = string
  default     = "vault"
}

variable "auth_mount" {
  description = "Kubernetes authentication mount path in Vault (must be a kubernetes auth type)"
  type        = string
  default     = "kubernetes"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.auth_mount))
    error_message = "Auth mount must contain only alphanumeric characters, hyphens, and underscores."
  }
}

# -----------------------------------------------------------------------------
# VAULT STATIC SECRETS CONFIGURATION
# -----------------------------------------------------------------------------

variable "secrets" {
  description = "List of Vault static secrets to retrieve and generate as Kubernetes secrets"

  type = list(object({
    name           = string                    # Name of the Kubernetes secret to create
    labels         = optional(object({}))      # Custom labels to apply to the Kubernetes secret
    mount          = string                    # Vault secrets engine mount path (e.g., 'secret', 'kv')
    type           = optional(string, "kv-v2") # Vault secrets engine type (kv-v1, kv-v2)
    version        = optional(number, 1)       # Secret version for kv-v2 (latest if not specified)
    path           = string                    # Path to the secret within the mount (e.g., 'app/config')
    refreshAfter   = optional(string, "30m")   # Interval to check for secret updates (e.g., 30m, 1h, 24h)
    transformation = optional(object({         # Optional data transformation settings
      excludes    = optional(list(string), []) # Keys to exclude from the secret
      includes    = optional(list(string), []) # Keys to include (empty = all keys)
      excludeRaw  = optional(bool, false)      # Exclude raw secret data from transformation
      templates   = optional(any, {})          # Template transformations for secret data
    }), {})
  }))

  # Validation rules
  validation {
    condition = alltrue([
      for secret in var.secrets : can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", secret.name))
    ])
    error_message = "Secret names must follow Kubernetes naming conventions (lowercase alphanumeric with hyphens)."
  }
  
  validation {
    condition = alltrue([
      for secret in var.secrets : can(regex("^[a-zA-Z0-9_/-]+$", secret.mount))
    ])
    error_message = "Mount paths must contain only alphanumeric characters, hyphens, underscores, and forward slashes."
  }
  
  validation {
    condition = alltrue([
      for secret in var.secrets : contains(["kv-v1", "kv-v2"], secret.type)
    ])
    error_message = "Secret type must be 'kv-v1' or 'kv-v2'."
  }
  
  validation {
    condition = alltrue([
      for secret in var.secrets : can(regex("^[a-zA-Z0-9_/-]+$", secret.path))
    ])
    error_message = "Secret paths must contain only alphanumeric characters, hyphens, underscores, and forward slashes."
  }
  
  validation {
    condition = alltrue([
      for secret in var.secrets : can(regex("^[0-9]+(s|m|h|d)$", secret.refreshAfter))
    ])
    error_message = "RefreshAfter must be in valid duration format (e.g., 30s, 5m, 1h, 24h)."
  }
  
  validation {
    condition = length(var.secrets) == length(distinct([for secret in var.secrets : secret.name]))
    error_message = "Secret names must be unique across all secrets."
  }
  
  validation {
    condition = alltrue([
      for secret in var.secrets : secret.version >= 1 || secret.type == "kv-v1"
    ])
    error_message = "Version must be >= 1 for kv-v2 secrets, or omitted for kv-v1."
  }
}