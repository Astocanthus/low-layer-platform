# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# -----------------------------------------------------------------------------
# KUBERNETES CONFIGURATION
# -----------------------------------------------------------------------------
variable "namespace" {
  description = "Namspace where to deploy module"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace))
    error_message = "Namespace must follow Kubernetes naming conventions."
  }
}

variable "infrastructure_namespace" {
  description = "Namespace where to find services"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.infrastructure_namespace))
    error_message = "Namespace must follow Kubernetes naming conventions."
  }
}

variable "keystone_namespace" {
  description = "Namespace where to find keystone"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.keystone_namespace))
    error_message = "Namespace must follow Kubernetes naming conventions."
  }
}

variable "timeout" {
  description = "Timeout"
  type        = string
}

