# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# CINDER RUNTIME SCRIPT DISTRIBUTION CONFIGURATION
# =============================================================================
# This resource provides a Kubernetes ConfigMap that distributes shell scripts
# used by the Cinder API or volume components during runtime operations.
# Scripts are typically used in entrypoints, lifecycle hooks, or as helper utilities.
# These files are mounted inside containers and executed by the runtime environment.

# -----------------------------------------------------------------------------
# CONFIGMAP FOR CINDER CONTAINER ENTRYPOINT SCRIPTS
# -----------------------------------------------------------------------------
# Creates a ConfigMap named 'cinder-bin' in the target namespace.
# All script files are dynamically loaded from the /files folder of this module.
# This configuration enables maintainable scripting without manual content duplication.

resource "kubernetes_config_map_v1" "cinder" {
  metadata {
    name      = "cinder-bin"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "cinder"
      "app.kubernetes.io/instance"   = "openstack-cinder"
      "app.kubernetes.io/component"  = "volume"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  # ---------------------------------------------------------------------------
  # DATA FROM FILES DIRECTORY
  # ---------------------------------------------------------------------------
  # Pattern: Load all files from a directory dynamically
  # Use case: Scripts, templates, or configuration files
  # Maintenance: Add/remove files in directory, no code changes needed
  # Mount: Files are mounted with their filename as the key

  data = {
    for filename in fileset("${path.module}/files", "*") :
    filename => file("${path.module}/files/${filename}")
  }
}