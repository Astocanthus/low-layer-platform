# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# PLACEMENT SCRIPT DISTRIBUTION CONFIGURATION
# =============================================================================
# This resource provides a Kubernetes ConfigMap that distributes support scripts
# required by the Placement API component. These scripts may include bootstrapping
# actions or runtime hooks used by containers.
# The data consists of shell scripts or configuration files bundled as plain text.
# The contents are intended to be mounted into pods as executable files.

# -----------------------------------------------------------------------------
# CONFIGMAP FOR PLACEMENT RUNTIME SCRIPTS
# -----------------------------------------------------------------------------
# Creates a ConfigMap named 'placement-bin' in the target namespace
# Scripts are loaded dynamically from the /source folder in this module.
# Maintenance is handled via physical file updates—no code change required
# for adding or removing scripts.

resource "kubernetes_config_map_v1" "placement" {
  metadata {
    name      = "placement-bin"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "placement"
      "app.kubernetes.io/instance"   = "openstack-placement"
      "app.kubernetes.io/component"  = "api"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  # ---------------------------------------------------------------------------
  # DATA FROM SOURCE DIRECTORY
  # ---------------------------------------------------------------------------
  # Pattern: Load all files from the source directory dynamically
  # Use case: Executable support scripts
  # Maintenance: Add/remove files in the source directory
  # Mount: Files are mounted using their base name as the key
  
  data = {
    for filename in fileset("${path.module}/source", "*") :
    filename => file("${path.module}/source/${filename}")
  }
}