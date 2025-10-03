# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# KUBERNETES NAMESPACE CONFIGURATION VARIABLES
# =============================================================================
# Variables for Kubernetes-based deployment configuration
# Defines deployment target namespace, shared infrastructure namespace,
# and general operational timeout settings for module orchestration

# -----------------------------------------------------------------------------
# MODULE DEPLOYMENT NAMESPACE CONFIGURATION
# -----------------------------------------------------------------------------
# Defines the target Kubernetes namespace used for deploying this module

variable "namespace" {
  description = "Kubernetes namespace where this module will be deployed"
  type        = string

  # Validation Rule: Enforces Kubernetes DNS-1123 naming convention
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace))
    error_message = "Namespace must follow Kubernetes naming conventions: lowercase alphanumeric characters, '-' allowed, must start/end with alphanumeric."
  }

  # Validation Rule: Ensures the namespace is not empty or whitespace only
  validation {
    condition     = length(trimspace(var.namespace)) > 0
    error_message = "Namespace cannot be empty or whitespace only."
  }
}

# -----------------------------------------------------------------------------
# INFRASTRUCTURE DEPENDENCIES NAMESPACE
# -----------------------------------------------------------------------------
# Specifies the namespace in which shared services such as RabbitMQ,
# MariaDB, or Memcached are deployed and made accessible

variable "infrastructure_namespace" {
  description = "Kubernetes namespace where shared infrastructure services are deployed (e.g. RabbitMQ, MariaDB)"
  type        = string

  # Validation Rule: Enforces Kubernetes DNS-1123 naming convention
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.infrastructure_namespace))
    error_message = "Infrastructure namespace must follow Kubernetes naming conventions: lowercase alphanumeric characters, '-' allowed, must start/end with alphanumeric."
  }

  # Validation Rule: Prevents empty or invalid namespace name
  validation {
    condition     = length(trimspace(var.infrastructure_namespace)) > 0
    error_message = "Infrastructure namespace cannot be empty or whitespace only."
  }
}

# -----------------------------------------------------------------------------
# TIMEOUT/OPERATIONAL CONFIGURATION
# -----------------------------------------------------------------------------
# Operational parameters for controlling timeout duration applied
# to module operations or deployments

variable "timeout" {
  description = "Timeout duration for resources and operations (e.g. 30s, 5m, 1h)"
  type        = string
  default     = "5m"

  # Validation Rule: Ensures format is an integer with a valid unit suffix
  validation {
    condition     = can(regex("^[0-9]+(s|m|h)$", var.timeout))
    error_message = "Timeout must be in format: number followed by s (seconds), m (minutes), or h (hours)."
  }

  # Validation Rule: Validates a reasonable operational range
  validation {
    condition = (
      tonumber(regex("[0-9]+", var.timeout)) >= 1 &&
      (
        (endswith(var.timeout, "s") && tonumber(regex("[0-9]+", var.timeout)) <= 3600) ||
        (endswith(var.timeout, "m") && tonumber(regex("[0-9]+", var.timeout)) <= 60) ||
        (endswith(var.timeout, "h") && tonumber(regex("[0-9]+", var.timeout)) <= 24)
      )
    )
    error_message = "Timeout must be reasonable: 1–3600s, 1–60m, or 1–24h."
  }
}