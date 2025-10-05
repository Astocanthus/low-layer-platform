# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# KEYSTONE SCRIPT DISTRIBUTION CONFIGURATION
# =============================================================================
# This resource provides a Kubernetes ConfigMap that distributes supporting shell
# scripts bundled with the Keystone API deployment (e.g., keystone-api.sh).
# These scripts are required at runtime (entrypoint, lifecycle hook, etc.) and must
# be mounted into the appropriate containers as executable files.

# -----------------------------------------------------------------------------
# CONFIGMAP FOR KEYSTONE RUNTIME SCRIPTS
# -----------------------------------------------------------------------------
# Creates a ConfigMap named 'keystone-bin' in the target namespace
# Scripts are loaded dynamically from the /files folder in this module.
# This pattern allows maintainable script injection without manual duplication.

resource "kubernetes_config_map" "keystone" {
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

  data = {
    for filename in fileset("${path.module}/files", "*") :
    filename => file("${path.module}/files/${filename}")
  }
}