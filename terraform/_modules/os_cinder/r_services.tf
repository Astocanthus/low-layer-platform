# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# CINDER API SERVICE
# =============================================================================
# Defines a Kubernetes Service for the Cinder API
# Exposes the block storage API over HTTPS within the cluster
# Routes traffic to pods running the Cinder API component using label selectors

# -----------------------------------------------------------------------------
# SERVICE CONFIGURATION
# -----------------------------------------------------------------------------
# Creates a ClusterIP service to expose Cinder on port 443
# Service type: ClusterIP for internal-only access within the Kubernetes cluster
# Enables in-cluster access and DNS resolution as volume-api.${namespace}.svc

resource "kubernetes_service_v1" "cinder_api" {
  metadata {
    name      = "volume-api"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "cinder"
      "app.kubernetes.io/instance"   = "openstack-cinder"
      "app.kubernetes.io/component"  = "api"
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
    # Incoming traffic on port 443 forwards to pods on port 443

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
      "app.kubernetes.io/name"      = "cinder"
      "app.kubernetes.io/instance"  = "openstack-cinder"
      "app.kubernetes.io/component" = "api"
    }
  }
}