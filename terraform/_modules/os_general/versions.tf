# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# -----------------------------------------------------------------------------
# TERRAFORM REQUIREMENTS
# -----------------------------------------------------------------------------
# Defines minimum versions and required providers for consistent deployments
# across different environments and team members

terraform {
  required_version = ">=1.3.3"
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = ">=2.16.0"
    }
  }
}