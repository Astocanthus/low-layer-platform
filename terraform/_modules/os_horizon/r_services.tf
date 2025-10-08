# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# HORIZON WEB SERVICE
# =============================================================================
# Defines a Kubernetes Service for Horizon Web UI
# Exposes the Horizon web interface over HTTPS within the cluster
# Routes traffic to pods running the Horizon server using label selectors

# -----------------------------------------------------------------------------
# SERVICE CONFIGURATION
# -----------------------------------------------------------------------------
# Creates a ClusterIP service to expose Horizon dashboard on port 443
# Service type: ClusterIP for internal access only
# Enables internal access and DNS resolution as horizon-web.<namespace>

resource "kubernetes_service_v1" "horizon_web" {
  metadata {
    name      = "horizon-web"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "horizon"
      "app.kubernetes.io/instance"   = "openstack-horizon"
      "app.kubernetes.io/component"  = "server"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  spec {
    # Service type determines accessibility scope
    # ClusterIP: Internal cluster access only
    type        = "ClusterIP"
    ip_families = ["IPv4"]

    # -------------------------------------------------------------------------
    # PORT DEFINITIONS
    # -------------------------------------------------------------------------
    # Port mapping for HTTPS traffic
    # Incoming traffic on port 443 forwards to pods on target port 443

    port {
      name        = "https"
      port        = 443
      target_port = "443"
      protocol    = "TCP"
    }

    # -------------------------------------------------------------------------
    # SELECTOR CONFIGURATION
    # -------------------------------------------------------------------------
    # Targets pods with matching labels to route traffic
    # Selectors must match pod labels exactly

    selector = {
      "app.kubernetes.io/name"      = "horizon"
      "app.kubernetes.io/instance"  = "openstack-horizon"
      "app.kubernetes.io/component" = "server"
    }
  }
}