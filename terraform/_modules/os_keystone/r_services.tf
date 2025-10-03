# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# KEYSTONE API SERVICE
# =============================================================================
# This resource defines a Kubernetes ClusterIP Service for the Keystone API.
# It exposes the Keystone API over HTTPS within the cluster and targets pods
# running the Keystone API component. The service routes traffic to the 
# appropriate pods using shared labels for selection.

# -----------------------------------------------------------------------------
# SERVICE CONFIGURATION
# -----------------------------------------------------------------------------
# Creates a ClusterIP service within the configured namespace to expose the
# Keystone API over port 443. The service uses IPv4 and selects matching pods
# labeled accordingly. This enables in-cluster access and internal DNS
# resolution under the service name.

resource "kubernetes_service_v1" "keystone_api" {
  metadata {
    name      = "keystone-api"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "keystone"
      "app.kubernetes.io/instance"   = "openstack-keystone"
      "app.kubernetes.io/component"  = "api"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  # -----------------------------------------------------------------------------
  # PORT DEFINITIONS
  # -----------------------------------------------------------------------------
  # Defines the service port mapping for HTTPS traffic. Traffic arriving on port
  # 443 is forwarded to target pods using the same port. The TCP protocol is used.

  spec {
    type        = "ClusterIP"
    ip_families = ["IPv4"]

    port {
      name        = "https"
      port        = 443
      target_port = "443"
      protocol    = "TCP"
    }

    # -----------------------------------------------------------------------------
    # SELECTOR CONFIGURATION
    # -----------------------------------------------------------------------------
    # Targets pods labeled as Keystone API component to route HTTPS traffic to them.

    selector = {
      "app.kubernetes.io/name"      = "keystone"
      "app.kubernetes.io/instance"  = "openstack-keystone"
      "app.kubernetes.io/component" = "api"
    }
  }
}