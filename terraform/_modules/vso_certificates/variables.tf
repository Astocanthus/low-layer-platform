# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# VAULT PKI CERTIFICATE MANAGEMENT VARIABLES
# =============================================================================
# This file defines the variables required for PKI certificate management
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
# VAULT PKI CONFIGURATION
# -----------------------------------------------------------------------------

variable "pki_name" {
  description = "Name of the PKI engine to use in Vault for certificate generation"
  type        = string
  default     = "pki"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.pki_name))
    error_message = "PKI name must contain only alphanumeric characters, hyphens, and underscores."
  }
}

variable "pki_issuer" {
  description = "Path to the issuer in the PKI engine for certificate generation"
  type        = string
  default     = "default"
}

variable "pki_role" {
  description = "Name of the PKI role to use for certificate generation in Vault"
  type        = string
  
  validation {
  condition     = can(regex("^[a-zA-Z0-9_.-]+$", var.pki_role))
  error_message = "PKI role must contain only alphanumeric characters, hyphens, underscores, and dots."

  }
}

# -----------------------------------------------------------------------------
# CERTIFICATE CONFIGURATION
# -----------------------------------------------------------------------------

variable "certificates" {
  description = "List of certificates to generate with their configuration parameters"
  
  type = list(object({
    cn           = string # Common Name (CN) of the certificate - usually the FQDN
    format       = string # Certificate output format (pem, der, pem_bundle)
    ttl          = string # Certificate lifetime (e.g., 24h, 30d, 1y)
    expiryOffset = string # Time before expiration to trigger renewal (e.g., 1h, 1d)
    secretName   = string # Name of the Kubernetes secret that will contain the certificate
    altNames     = optional(list(string), []) # Alternative Names to include in certificate (SAN)
  }))
  
  default = [{
    cn           = "default.internal"
    format       = "pem"
    ttl          = "24h"
    expiryOffset = "1h"
    secretName   = "default-tls-cert"
  }]
  
  validation {
    condition = alltrue([
      for cert in var.certificates : can(regex("^[a-zA-Z0-9.-]+$", cert.cn))
    ])
    error_message = "Common Names must be valid domain names."
  }
  
  validation {
    condition = alltrue([
      for cert in var.certificates : contains(["pem", "der", "pem_bundle"], cert.format)
    ])
    error_message = "Format must be 'pem', 'der', or 'pem_bundle'."
  }
  
  validation {
    condition = alltrue([
      for cert in var.certificates : can(regex("^[0-9]+(h|d|m|s|y)$", cert.ttl))
    ])
    error_message = "TTL must be in valid format (e.g., 24h, 30d, 1y)."
  }
  
  validation {
    condition = alltrue([
      for cert in var.certificates : can(regex("^[0-9]+(h|d|m|s|y)$", cert.expiryOffset))
    ])
    error_message = "ExpiryOffset must be in valid format (e.g., 1h, 1d)."
  }
  
  validation {
    condition = alltrue([
      for cert in var.certificates : can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", cert.secretName))
    ])
    error_message = "Secret names must follow Kubernetes naming conventions."
  }
  
  validation {
    condition = length(var.certificates) == length(distinct([for cert in var.certificates : cert.secretName]))
    error_message = "Secret names must be unique across all certificates."
  }

  validation {
    condition = alltrue([
      for cert in var.certificates : alltrue([
        for altName in cert.altNames : can(regex("^[a-zA-Z0-9.*-]+$", altName))
      ])
    ])
    error_message = "All alternative names must be valid domain names or IP addresses."
  }

  # Validation pour éviter la duplication entre CN et altNames
  validation {
    condition = alltrue([
      for cert in var.certificates : !contains(cert.altNames, cert.cn)
    ])
    error_message = "Common Name should not be duplicated in alternative names."
  }
}