# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# OPENSTACK SERVICE DEPLOYMENT CONFIGURATION VARIABLES
# =============================================================================
# Variables for configuring namespace placement and inter-service dependencies
# Defines OpenStack service locations, namespace references, and operational timeout
# Input used to parameterize deployment across Kubernetes namespaces

# -----------------------------------------------------------------------------
# TARGET NAMESPACE CONFIGURATION
# -----------------------------------------------------------------------------
# Namespace in which the current module will deploy OpenStack resources

variable "namespace" {
  description = "Target Kubernetes namespace where OpenStack module resources will be deployed"
  type        = string

  # Validation Rule: Namespace format must follow Kubernetes DNS label standards
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace))
    error_message = "Namespace must follow Kubernetes naming conventions (lowercase alphanumeric, may contain hyphens)."
  }

  # Validation Rule: Namespace string must not be empty
  validation {
    condition     = length(trimspace(var.namespace)) > 0
    error_message = "Namespace cannot be empty or contain only whitespace."
  }
}

# -----------------------------------------------------------------------------
# SERVICE DEPENDENCY NAMESPACES
# -----------------------------------------------------------------------------
# External namespaces where core dependent services are deployed

variable "infrastructure_namespace" {
  description = "Kubernetes namespace hosting foundational infrastructure services (e.g. RabbitMQ, MariaDB, Memcached)"
  type        = string

  # Validation Rule: Must comply with Kubernetes DNS label naming
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.infrastructure_namespace))
    error_message = "Infrastructure namespace must follow Kubernetes naming conventions (lowercase alphanumeric, may contain hyphens)."
  }

  # Validation Rule: Value must not be empty
  validation {
    condition     = length(trimspace(var.infrastructure_namespace)) > 0
    error_message = "Infrastructure namespace cannot be empty or contain only whitespace."
  }
}

variable "keystone_namespace" {
  description = "Kubernetes namespace hosting the Keystone identity service"
  type        = string

  # Validation Rule: Must match Kubernetes naming format
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.keystone_namespace))
    error_message = "Keystone namespace must follow Kubernetes naming conventions (lowercase alphanumeric, may contain hyphens)."
  }

  # Validation Rule: Value must not be empty
  validation {
    condition     = length(trimspace(var.keystone_namespace)) > 0
    error_message = "Keystone namespace cannot be empty or contain only whitespace."
  }
}

variable "glance_namespace" {
  description = "Kubernetes namespace hosting the Glance image service"
  type        = string

  # Validation Rule: Kubernetes namespace name compliance
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.glance_namespace))
    error_message = "Glance namespace must follow Kubernetes naming conventions (lowercase alphanumeric, may contain hyphens)."
  }

  # Validation Rule: Must contain non-whitespace content
  validation {
    condition     = length(trimspace(var.glance_namespace)) > 0
    error_message = "Glance namespace cannot be empty or contain only whitespace."
  }
}

variable "neutron_namespace" {
  description = "Kubernetes namespace hosting the Neutron networking service"
  type        = string

  # Validation Rule: Ensure valid Kubernetes-style namespace
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.neutron_namespace))
    error_message = "Neutron namespace must follow Kubernetes naming conventions (lowercase alphanumeric, may contain hyphens)."
  }

  # Validation Rule: Must not be empty string
  validation {
    condition     = length(trimspace(var.neutron_namespace)) > 0
    error_message = "Neutron namespace cannot be empty or contain only whitespace."
  }
}

# -----------------------------------------------------------------------------
# OPERATIONAL SETTINGS
# -----------------------------------------------------------------------------
# Execution-related parameters for provisioning workflows

variable "timeout" {
  description = "Default timeout duration for provisioning or initialization operations (e.g., health checks, deployment rolls)"
  type        = string

  # Validation Rule: Format must match time duration syntax
  validation {
    condition     = can(regex("^[0-9]+(s|m|h)$", var.timeout))
    error_message = "Timeout must be in format: number followed by s (seconds), m (minutes), or h (hours)."
  }

  # Validation Rule: Range must be bounded within reasonable operational limits
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