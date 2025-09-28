# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# GENERAL BINARY CONFIGMAP DEPLOYMENT
# =============================================================================
# Deploy shared binary and script ConfigMaps across OpenStack service namespaces
# Provides common utilities and initialization scripts for OpenStack components

# -----------------------------------------------------------------------------
# GENERAL BINARY CONFIGMAP CONFIGURATION
# -----------------------------------------------------------------------------
# Centralized configuration for binary script distribution

locals {
  configmap_config = {
    name        = "general-bin"
    source_path = "${path.module}/source"
  }
}

# -----------------------------------------------------------------------------
# GENERAL BINARY CONFIGMAP
# -----------------------------------------------------------------------------
# ConfigMap containing shared scripts and binaries for OpenStack services
# Deployed across all unique namespaces for consistent tooling availability

resource "kubernetes_config_map" "general_bin" {
  for_each = local.unique_namespaces
  
  metadata {
    name      = local.configmap_config.name
    namespace = each.value
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "shared-scripts"
      "app.kubernetes.io/part-of"    = "openstack-infrastructure"
      "config.openstack.org/type"    = "binary"
    }
  }

  # Load all files from source directory into ConfigMap data
  data = {
    for filename in fileset(local.configmap_config.source_path, "*") : 
      filename => file("${local.configmap_config.source_path}/${filename}")
  }

  # Lifecycle management for script updates
  lifecycle {
    create_before_destroy = true
  }
}