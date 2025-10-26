# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# KUBERNETES NAMESPACE CONFIGURATION VARIABLES
# =============================================================================
# Variables for configuring Kubernetes namespaces used by this module
# Defines target, infrastructure, and identity service namespaces
# Ensures naming conventions and isolation compatibility within a Kubernetes context

# -----------------------------------------------------------------------------
# TARGET NAMESPACE CONFIGURATION
# -----------------------------------------------------------------------------
# Namespace where the module resources will be deployed

variable "namespace" {
  description = "Kubernetes namespace where this module will be deployed"
  type        = string

  # Validation Rule: Ensure namespace follows Kubernetes naming convention
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace))
    error_message = "Namespace must follow Kubernetes naming conventions (lowercase, alphanumeric, hyphens allowed)."
  }

  # Validation Rule: Ensure namespace is not empty or only whitespaces
  validation {
    condition     = length(trimspace(var.namespace)) > 0
    error_message = "Namespace cannot be empty or whitespace only."
  }
}

# -----------------------------------------------------------------------------
# INFRASTRUCTURE NAMESPACE REFERENCE
# -----------------------------------------------------------------------------
# Namespace containing shared infrastructure services required by the module

variable "infrastructure_namespace" {
  description = "Kubernetes namespace containing infrastructure services like messaging, databases, and cache layers"
  type        = string

  # Validation Rule: Ensure namespace follows Kubernetes naming convention
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.infrastructure_namespace))
    error_message = "Infrastructure namespace must follow Kubernetes naming conventions (lowercase, alphanumeric, hyphens allowed)."
  }

  # Validation Rule: Ensure namespace is not empty or only whitespaces
  validation {
    condition     = length(trimspace(var.infrastructure_namespace)) > 0
    error_message = "Infrastructure namespace cannot be empty or whitespace only."
  }
}

# -----------------------------------------------------------------------------
# KEYSTONE NAMESPACE REFERENCE
# -----------------------------------------------------------------------------
# Namespace containing the Keystone identity service for authentication

variable "keystone_namespace" {
  description = "Kubernetes namespace where the Keystone identity service is deployed"
  type        = string

  # Validation Rule: Ensure namespace follows Kubernetes naming convention
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.keystone_namespace))
    error_message = "Keystone namespace must follow Kubernetes naming conventions (lowercase, alphanumeric, hyphens allowed)."
  }

  # Validation Rule: Ensure namespace is not empty or only whitespaces
  validation {
    condition     = length(trimspace(var.keystone_namespace)) > 0
    error_message = "Keystone namespace cannot be empty or whitespace only."
  }
}

# -----------------------------------------------------------------------------
# OPERATIONAL CONFIGURATION
# -----------------------------------------------------------------------------
# Timeout used for resource provisioning and operations execution

variable "timeout" {
  description = "Timeout duration for module operations and resource initialization (examples: 30s, 5m, 1h)"
  type        = string
  default     = "5m"

  # Validation Rule: Ensure timeout is in correct format (e.g., 10s, 5m, 1h)
  validation {
    condition     = can(regex("^[0-9]+(s|m|h)$", var.timeout))
    error_message = "Timeout must be in format: number followed by s (seconds), m (minutes), or h (hours)."
  }

  # Validation Rule: Ensure timeout is within a reasonable range
  validation {
    condition = (
      tonumber(regex("[0-9]+", var.timeout)) >= 1 &&
      (
        (endswith(var.timeout, "s") && tonumber(regex("[0-9]+", var.timeout)) <= 3600) ||
        (endswith(var.timeout, "m") && tonumber(regex("[0-9]+", var.timeout)) <= 60) ||
        (endswith(var.timeout, "h") && tonumber(regex("[0-9]+", var.timeout)) <= 24)
      )
    )
    error_message = "Timeout must be reasonable: 1-3600s, 1-60m, or 1-24h."
  }
}