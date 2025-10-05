# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# HORIZON CONFIGMAPS FOR STATIC ASSETS AND BINARIES
# =============================================================================
# This file provisions two ConfigMaps used by the Horizon dashboard:
# one contains static logo assets in base64 format,
# and the other provides initialization scripts or support files in raw text.
# These ConfigMaps are used at Pod runtime via volume mounts in the Horizon PodSpec.

# -----------------------------------------------------------------------------
# STATIC LOGO CONFIGMAP
# -----------------------------------------------------------------------------
# Stores binary logo files (e.g., PNG, SVG) used by Horizon UI as a ConfigMap.
# Each file is base64-encoded due to the Kubernetes binary_data requirement.
# The logo files are located under the ./logo directory relative to this module.

resource "kubernetes_config_map" "horizon_logo" {
  metadata {
    name      = "horizon-logo"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "horizon"
      "app.kubernetes.io/instance"   = "openstack-horizon"
      "app.kubernetes.io/component"  = "ui"
      "app.kubernetes.io/part-of"    = "openstack"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  binary_data = {
    for filename in fileset("${path.module}/logo", "*") :
    filename => base64encode(file("${path.module}/logo/${filename}"))
  }
}

# -----------------------------------------------------------------------------
# SUPPORT BINARIES CONFIGMAP
# -----------------------------------------------------------------------------
# Bundles executable scripts or configuration files required during Horizon startup.
# Files from the ./source directory are mounted in the Horizon Pod's filesystem.
# Unlike binary_data, content is injected as plain UTF-8 strings.

resource "kubernetes_config_map" "horizon_bin" {
  metadata {
    name      = "horizon-bin"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "horizon"
      "app.kubernetes.io/instance"   = "openstack-horizon"
      "app.kubernetes.io/component"  = "ui"
      "app.kubernetes.io/part-of"    = "openstack"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    for filename in fileset("${path.module}/source", "*") :
    filename => file("${path.module}/source/${filename}")
  }
}