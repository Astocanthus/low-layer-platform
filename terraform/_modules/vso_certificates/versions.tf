# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

terraform {
  required_version = ">=1.3.3"
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.16.0"
    }
  }
}