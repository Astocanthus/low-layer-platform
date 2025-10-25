# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# GLANCE RUNTIME SCRIPT CONFIGURATION
# =============================================================================
# This resource provides a Kubernetes ConfigMap that distributes shell scripts
# required at runtime for Glance container workloads. These scripts are used
# for container entrypoints, lifecycle hooks, or operational utilities.
# They are intended to be mounted into containers as executable files during runtime.

# -----------------------------------------------------------------------------
# CONFIGMAP FOR GLANCE SUPPORTING SCRIPTS
# -----------------------------------------------------------------------------
# Creates a ConfigMap named 'glance-bin' in the specified namespace
# Scripts are dynamically loaded from the 'files' directory in the module
# Each script is injected using its filename as the key
# Allows easy maintenance by adding/removing files without modifying this file

resource "kubernetes_config_map_v1" "glance_bin" {
  metadata {
    name      = "glance-bin"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "glance"
      "app.kubernetes.io/instance"   = "openstack-glance"
      "app.kubernetes.io/component"  = "api"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  data = {
    for filename in fileset("${path.module}/files", "*") :
    filename => file("${path.module}/files/${filename}")
  }
}