# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# KUBERNETES CONFIGURATION VARIABLES
# =============================================================================
# Variables for Kubernetes resource configuration
# Defines the namespace placement, cross-service references, and operational settings
# Used to control deployment scope, CA configuration, and resource timing

# -----------------------------------------------------------------------------
# NAMESPACE CONFIGURATION
# -----------------------------------------------------------------------------
# Defines project and infrastructure namespace contexts
# Used to isolate and scope Kubernetes resources for logical grouping and access

variable "namespace" {
  description = "Kubernetes namespace in which to deploy the module resources"
  type        = string

  # Validation Rule: Enforces Kubernetes DNS-compliant naming convention
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace))
    error_message = "Namespace must follow Kubernetes naming conventions (lowercase alphanumeric characters or hyphens, must start and end with an alphanumeric character)."
  }

  # Validation Rule: Non-empty check
  validation {
    condition     = length(trimspace(var.namespace)) > 0
    error_message = "Namespace cannot be empty or only contain whitespace."
  }
}

variable "infrastructure_namespace" {
  description = "Kubernetes namespace containing shared infrastructure services such as RabbitMQ, MariaDB, or Memcached"
  type        = string

  # Validation Rule: Enforces Kubernetes DNS-compliant naming convention
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.infrastructure_namespace))
    error_message = "Infrastructure namespace must follow Kubernetes naming conventions (lowercase alphanumeric characters or hyphens, must start and end with an alphanumeric character)."
  }

  # Validation Rule: Non-empty check
  validation {
    condition     = length(trimspace(var.infrastructure_namespace)) > 0
    error_message = "Infrastructure namespace cannot be empty or only contain whitespace."
  }
}

variable "keystone_namespace" {
  description = "Kubernetes namespace containing the OpenStack Keystone service"
  type        = string

  # Validation Rule: Enforces Kubernetes DNS-compliant naming convention
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.keystone_namespace))
    error_message = "Keystone namespace must follow Kubernetes naming conventions (lowercase alphanumeric characters or hyphens, must start and end with an alphanumeric character)."
  }

  # Validation Rule: Non-empty check
  validation {
    condition     = length(trimspace(var.keystone_namespace)) > 0
    error_message = "Keystone namespace cannot be empty or only contain whitespace."
  }
}

# -----------------------------------------------------------------------------
# CERTIFICATE AUTHORITY CONFIGURATION
# -----------------------------------------------------------------------------
# Configures access to the internal CA secret used by services
# Ensures TLS trust validation for internal communication

variable "local_ca_secret_name" {
  description = "Name of the Kubernetes Secret containing the local root certificate authority (CA)"
  type        = string

  # Validation Rule: Enforces Kubernetes DNS-compliant naming convention
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.local_ca_secret_name))
    error_message = "Secret name must follow Kubernetes naming conventions (lowercase alphanumeric characters or hyphens, must start and end with an alphanumeric character)."
  }

  # Validation Rule: Non-empty check
  validation {
    condition     = length(trimspace(var.local_ca_secret_name)) > 0
    error_message = "Secret name cannot be empty or only contain whitespace."
  }
}

# -----------------------------------------------------------------------------
# TIMEOUT CONFIGURATION
# -----------------------------------------------------------------------------
# Timeout setting for Kubernetes operations and module provisioning behaviors

variable "timeout" {
  description = "Duration for timeout operations when provisioning or interacting with Kubernetes resources"
  type        = string

  # Validation Rule: Format check (e.g., 30s, 5m, 1h)
  validation {
    condition     = can(regex("^[0-9]+(s|m|h)$", var.timeout))
    error_message = "Timeout must follow the pattern: number followed by a time unit (s, m, h)."
  }

  # Validation Rule: Ensure the timeout is within reasonable bounds
  validation {
    condition = (
      tonumber(regex("[0-9]+", var.timeout)) >= 1 &&
      (
        (endswith(var.timeout, "s") && tonumber(regex("[0-9]+", var.timeout)) <= 3600) ||
        (endswith(var.timeout, "m") && tonumber(regex("[0-9]+", var.timeout)) <= 60) ||
        (endswith(var.timeout, "h") && tonumber(regex("[0-9]+", var.timeout)) <= 24)
      )
    )
    error_message = "Timeout must be within the following ranges: 1-3600s, 1-60m, or 1-24h."
  }
}