# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# KEYSTONE RUNTIME SCRIPT CONFIGURATION
# =============================================================================
# This resource provides a Kubernetes ConfigMap used to distribute runtime shell
# scripts required by the Keystone API deployment (e.g., keystone-api.sh).
# These scripts are intended to be mounted as executable files in containers
# and are used at runtime via entrypoints, lifecycle hooks, etc.
# 
# This ConfigMap stores executable shell script files and supports dynamic loading
# from the module's /files directory. The pattern improves reusability and
# simplifies maintenance by avoiding manual key definitions.

# -----------------------------------------------------------------------------
# CONFIGMAP FOR KEYSTONE EXECUTION SCRIPTS
# -----------------------------------------------------------------------------
# Creates a ConfigMap named 'keystone-bin' in the specified namespace.
# Load all script files dynamically from the '/files' directory in this module.
# Maintenance: Add and remove script files in '/files' without modifying code.
# Usage: Scripts will be mounted into containers at runtime using volume mounting.

resource "kubernetes_config_map_v1" "keystone" {
  metadata {
    name      = "keystone-bin"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "keystone"
      "app.kubernetes.io/instance"   = "openstack-keystone"
      "app.kubernetes.io/component"  = "api"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  # ---------------------------------------------------------------------------
  # LOAD ALL FILES FROM MODULE FILES DIRECTORY
  # ---------------------------------------------------------------------------
  # Pattern: Load all files in /files using fileset() function
  # Maintains original filenames as keys in config map
  # Consumption: Expected to be mounted as files in containers

  data = {
    for filename in fileset("${path.module}/files", "*") :
    filename => file("${path.module}/files/${filename}")
  }
}