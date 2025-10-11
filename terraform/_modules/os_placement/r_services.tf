# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# PLACEMENT API SERVICE
# =============================================================================
# Defines a Kubernetes Service for the Placement API component.
# Exposes the Placement API over HTTPS within the cluster.
# Routes traffic to pods running the Placement API using label selectors.

# -----------------------------------------------------------------------------
# SERVICE CONFIGURATION
# -----------------------------------------------------------------------------
# Creates a ClusterIP service to expose the Placement API on port 443.
# Service type: ClusterIP for internal-only access between Kubernetes workloads.
# Enables in-cluster service discovery via placement-api.<namespace> DNS mapping.

resource "kubernetes_service_v1" "placement_api" {
  metadata {
    name      = "placement-api"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "placement"
      "app.kubernetes.io/instance"   = "openstack-placement"
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
    # Targets pods with matching labels to route HTTPS traffic to Placement API

    selector = {
      "app.kubernetes.io/name"      = "placement"
      "app.kubernetes.io/instance"  = "openstack-placement"
      "app.kubernetes.io/component" = "api"
    }
  }
}