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
    redfish = {
      version = ">=1.6.0"
      source  = "registry.terraform.io/dell/redfish" # Official Dell provider
    }
  }
}