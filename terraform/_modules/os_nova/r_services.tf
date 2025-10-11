# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# NOVA API SERVICE
# =============================================================================
# Defines a Kubernetes Service for the Nova API
# Exposes the Compute API over HTTPS within the cluster
# Routes traffic to pods running the Nova API component using label selectors

# -----------------------------------------------------------------------------
# SERVICE CONFIGURATION
# -----------------------------------------------------------------------------
# Creates a ClusterIP service to expose the Nova API on port 443
# Service type: ClusterIP for internal access between OpenStack components
# Enables internal service access and DNS resolution as compute-api.<namespace>

resource "kubernetes_service_v1" "nova_api" {
  metadata {
    name      = "compute-api"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "nova"
      "app.kubernetes.io/instance"   = "openstack-nova"
      "app.kubernetes.io/component"  = "api"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  spec {
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

    selector = {
      "app.kubernetes.io/name"      = "nova"
      "app.kubernetes.io/instance"  = "openstack-nova"
      "app.kubernetes.io/component" = "api"
    }
  }
}

# =============================================================================
# NOVA METADATA SERVICE
# =============================================================================
# Defines a Kubernetes Service for the Nova Metadata API
# Exposes the Metadata service over HTTPS within the cluster
# Routes traffic to pods running the Nova Metadata component using label selectors

# -----------------------------------------------------------------------------
# SERVICE CONFIGURATION
# -----------------------------------------------------------------------------
# Creates a ClusterIP service to expose Nova Metadata on port 443
# Service type: ClusterIP for internal access by instances or config agent
# Enables internal service access and DNS resolution as compute-metadata.<namespace>

resource "kubernetes_service_v1" "nova_metadata" {
  metadata {
    name      = "compute-metadata"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "nova"
      "app.kubernetes.io/instance"   = "openstack-nova"
      "app.kubernetes.io/component"  = "metadata"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  spec {
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

    selector = {
      "app.kubernetes.io/name"      = "nova"
      "app.kubernetes.io/instance"  = "openstack-nova"
      "app.kubernetes.io/component" = "metadata"
    }
  }
}

# =============================================================================
# NOVA NOVNCPROXY SERVICE
# =============================================================================
# Defines a Kubernetes Service for the Nova noVNC Proxy
# Exposes the noVNC proxy over HTTPS within the cluster
# Routes traffic to pods running the Nova noVNC Proxy component using label selectors

# -----------------------------------------------------------------------------
# SERVICE CONFIGURATION
# -----------------------------------------------------------------------------
# Creates a ClusterIP service to expose Nova noVNC Proxy on port 443
# Service type: ClusterIP for internal access to the console service
# Enables internal service access and DNS resolution as compute-novncproxy.<namespace>

resource "kubernetes_service_v1" "nova_novncproxy" {
  metadata {
    name      = "compute-novncproxy"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "nova"
      "app.kubernetes.io/instance"   = "openstack-nova"
      "app.kubernetes.io/component"  = "novncproxy"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  spec {
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

    selector = {
      "app.kubernetes.io/name"      = "nova"
      "app.kubernetes.io/instance"  = "openstack-nova"
      "app.kubernetes.io/component" = "novncproxy"
    }
  }
}