# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# KUBERNETES DEPLOYMENT CONFIGURATION VARIABLES
# =============================================================================
# Variables for Kubernetes namespace configuration and operational controls
# Defines the namespaces used across service components and supports deployment
# of OpenStack-related modules within the defined Kubernetes scopes

# -----------------------------------------------------------------------------
# NAMESPACE CONFIGURATION
# -----------------------------------------------------------------------------
# Kubernetes namespaces for component discovery and deployment segregation

variable "namespace" {
  description = "Kubernetes namespace where this module will be deployed"
  type        = string

  # Validation: Enforce Kubernetes naming conventions
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace))
    error_message = "Namespace must follow Kubernetes naming conventions (lowercase, alphanumeric, hyphens allowed)."
  }

  # Validation: Enforce namespace cannot be empty
  validation {
    condition     = length(trimspace(var.namespace)) > 0
    error_message = "Namespace cannot be empty or whitespace only."
  }
}

variable "infrastructure_namespace" {
  description = "Kubernetes namespace where shared infrastructure services are located (e.g., RabbitMQ, MariaDB)"
  type        = string

  # Validation: Enforce Kubernetes naming conventions
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.infrastructure_namespace))
    error_message = "Namespace must follow Kubernetes naming conventions (lowercase, alphanumeric, hyphens allowed)."
  }

  # Validation: Enforce namespace cannot be empty
  validation {
    condition     = length(trimspace(var.infrastructure_namespace)) > 0
    error_message = "Infrastructure namespace cannot be empty or whitespace only."
  }
}

variable "keystone_namespace" {
  description = "Kubernetes namespace where OpenStack Keystone identity service is deployed"
  type        = string

  # Validation: Enforce Kubernetes naming conventions
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.keystone_namespace))
    error_message = "Namespace must follow Kubernetes naming conventions (lowercase, alphanumeric, hyphens allowed)."
  }

  # Validation: Enforce namespace cannot be empty
  validation {
    condition     = length(trimspace(var.keystone_namespace)) > 0
    error_message = "Keystone namespace cannot be empty or whitespace only."
  }
}

# -----------------------------------------------------------------------------
# OPERATIONAL CONFIGURATION
# -----------------------------------------------------------------------------
# Configuration for deployment timeouts and execution delays

variable "timeout" {
  description = "Default timeout duration for operational tasks (e.g., job completion, provisioning)"
  type        = string

  # Validation: Enforce duration format
  validation {
    condition     = can(regex("^[0-9]+(s|m|h)$", var.timeout))
    error_message = "Timeout must be in format: number followed by s (seconds), m (minutes), or h (hours)."
  }

  # Validation: Enforce reasonable timeout ranges depending on unit
  validation {
    condition = (
      tonumber(regex("[0-9]+", var.timeout)) >= 1 &&
      (
        (endswith(var.timeout, "s") && tonumber(regex("[0-9]+", var.timeout)) <= 3600) ||
        (endswith(var.timeout, "m") && tonumber(regex("[0-9]+", var.timeout)) <= 60)   ||
        (endswith(var.timeout, "h") && tonumber(regex("[0-9]+", var.timeout)) <= 24)
      )
    )
    error_message = "Timeout must be reasonable: 1-3600s, 1-60m, or 1-24h."
  }
}