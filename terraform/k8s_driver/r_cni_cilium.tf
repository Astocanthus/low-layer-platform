# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# CILIUM CNI DEPLOYMENT
# =============================================================================
# Deploy Cilium CNI with advanced networking capabilities including
# LoadBalancer IP pools and L2 announcement policies for multi-interface setup

# -----------------------------------------------------------------------------
# NETWORK CONFIGURATION VARIABLES
# -----------------------------------------------------------------------------
# Define network interfaces and their corresponding IP ranges
# This enables flexible multi-network LoadBalancer configurations

locals {
  # Network interface configurations
  # Each interface serves a specific purpose with dedicated IP ranges and security policies
  network_interfaces = {
    eno1 = {
      interface_name = "eno1"
      network_type   = "internal"
      ip_range = {
        start = "192.168.3.150"
        stop  = "192.168.3.250"
      }
      # Empty node selector means all nodes can use this interface
      node_selector = {}
      description   = "Internal network interface for cluster-internal services and management"
    }
    eno2 = {
      interface_name = "eno2"
      network_type   = "public-api"
      ip_range = {
        start = "192.168.4.150"
        stop  = "192.168.4.250"
      }
      # Restrict to control plane nodes only for security
      node_selector = {
        "node.kubernetes.io/control-plane" = ""
      }
      description = "Public API network interface for external-facing services and APIs"
    }
  }

  # Cilium configuration
  cilium_config = {
    chart_version = "1.18.1"
    namespace     = "kube-system"
    repository    = "https://helm.cilium.io/"
  }
}

# -----------------------------------------------------------------------------
# CILIUM CNI HELM DEPLOYMENT
# -----------------------------------------------------------------------------
# Deploys Cilium as the primary CNI provider with LoadBalancer capabilities
# Uses external configuration file for detailed Cilium settings

resource "helm_release" "cni_cilium" {
  name       = "cni-cilium"
  repository = local.cilium_config.repository
  chart      = "cilium"
  version    = local.cilium_config.chart_version
  namespace  = local.cilium_config.namespace

  # Load Cilium configuration from external values file
  # This approach separates infrastructure config from application-specific settings
  values = [
    file("helm_values/cni_cilium_config.yaml")
  ]

  # Ensure proper cleanup order
  wait          = true
  wait_for_jobs = true
  timeout       = 300

  # Force recreation if chart version changes
  force_update    = false
  recreate_pods   = false
  cleanup_on_fail = true
}

# -----------------------------------------------------------------------------
# L2 ANNOUNCEMENT POLICIES
# -----------------------------------------------------------------------------
# Creates L2 announcement policies for each network interface
# Enables LoadBalancer services to be announced on specific network segments

resource "kubectl_manifest" "cilium_l2_policies" {
  for_each = local.network_interfaces

  yaml_body = yamlencode({
    apiVersion = "cilium.io/v2alpha1"
    kind       = "CiliumL2AnnouncementPolicy"
    metadata = {
      name = "l2-policy-${each.key}"
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/component"  = "cilium-l2-policy"
        "network.low-layer.com/interface" = each.key
        "network.low-layer.com/type"      = each.value.network_type
      }
    }
    spec = {
      # Service selector using interface-specific labels
      serviceSelector = {
        matchLabels = {
          "cilium.io/lb-interface" = each.key
        }
      }
      # Node selector configuration (empty for all nodes, or specific labels)
      nodeSelector = each.value.node_selector
      # Network interfaces for L2 announcements
      interfaces = [each.value.interface_name]
      # Enable external and LoadBalancer IP announcements
      externalIPs     = true
      loadBalancerIPs = true
    }
  })

  # Ensure Cilium is deployed before creating L2 policies
  depends_on = [helm_release.cni_cilium]
}

# -----------------------------------------------------------------------------
# LOADBALANCER IP POOLS
# -----------------------------------------------------------------------------
# Creates LoadBalancer IP pools for each network interface
# Provides dedicated IP ranges for LoadBalancer services per network segment

resource "kubectl_manifest" "cilium_loadbalancer_pools" {
  for_each = local.network_interfaces

  yaml_body = yamlencode({
    apiVersion = "cilium.io/v2"
    kind       = "CiliumLoadBalancerIPPool"
    metadata = {
      name = "lb-pool-${each.key}"
      labels = {
        "app.kubernetes.io/managed-by"    = "terraform"
        "app.kubernetes.io/component"     = "cilium-lb-pool"
        "network.low-layer.com/interface" = each.key
        "network.low-layer.com/range"     = "${each.value.ip_range.start}-${each.value.ip_range.stop}"
      }
    }
    spec = {
      # Service selector using interface-specific labels
      serviceSelector = {
        matchLabels = {
          "cilium.io/lb-interface" = each.key
        }
      }
      # IP address blocks for LoadBalancer allocation
      blocks = [
        {
          start = each.value.ip_range.start
          stop  = each.value.ip_range.stop
        }
      ]
    }
  })

  # Ensure Cilium is deployed before creating IP pools
  depends_on = [helm_release.cni_cilium]
}
