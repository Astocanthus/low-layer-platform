# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# VAULT CONFIGURATION VARIABLES
# =============================================================================
# Configuration variables for Vault deployment and service integrations
# Provides secure and flexible configuration management

# -----------------------------------------------------------------------------
# KUBERNETES OIDC CONFIGURATION
# -----------------------------------------------------------------------------
variable "k8s_oidc_client_id" {
  description = "OIDC client identifier used by kube-apiserver for authentication"
  type        = string
  default     = "kubernetes"

  validation {
    condition     = length(var.k8s_oidc_client_id) > 0
    error_message = "Kubernetes OIDC client ID cannot be empty."
  }
}

# -----------------------------------------------------------------------------
# AWS ROUTE53 CREDENTIALS
# -----------------------------------------------------------------------------
# AWS credentials for Route53 DNS provider integration with ACME certificates
# Required for Let's Encrypt domain validation challenges

variable "aws_access_key_id" {
  description = "AWS Access Key ID for Route53 DNS provider authentication"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.aws_access_key_id) > 0
    error_message = "AWS Access Key ID cannot be empty."
  }
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key for Route53 DNS provider authentication"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.aws_secret_access_key) > 0
    error_message = "AWS Secret Access Key cannot be empty."
  }
}