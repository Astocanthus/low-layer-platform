# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# GLANCE API SERVICE
# =============================================================================
# Defines a Kubernetes Service for the Glance API (Image Service)
# Exposes Glance over HTTPS within the cluster
# Routes traffic to pods running the Glance API component using label selectors

# -----------------------------------------------------------------------------
# SERVICE CONFIGURATION
# -----------------------------------------------------------------------------
# Creates a ClusterIP service to expose Glance API on port 443
# Service type: ClusterIP for internal access
# Enables in-cluster access and DNS resolution as image-api.<namespace>

resource "kubernetes_service_v1" "glance_api" {
  metadata {
    name      = "image-api"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "glance"
      "app.kubernetes.io/instance"   = "openstack-glance"
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
    # Incoming traffic on port 443 forwards to pods on target port 8443
    
    port {
      name        = "https"
      port        = 443
      target_port = 8443
      protocol    = "TCP"
    }

    # -------------------------------------------------------------------------
    # SELECTOR CONFIGURATION
    # -------------------------------------------------------------------------
    # Targets pods with matching labels to route traffic
    # Selectors must match pod labels exactly
    
    selector = {
      "app.kubernetes.io/name"      = "glance"
      "app.kubernetes.io/instance"  = "openstack-glance"
      "app.kubernetes.io/component" = "api"
    }
  }
}