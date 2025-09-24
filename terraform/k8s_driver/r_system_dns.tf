# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# SYSTEM COREDNS DEPLOYMENT
# =============================================================================
# Deploy CoreDNS as the primary DNS server for Kubernetes cluster
# Provides DNS resolution for services, pods, and external domains

# -----------------------------------------------------------------------------
# COREDNS CONFIGURATION
# -----------------------------------------------------------------------------
# Centralized configuration for CoreDNS deployment

locals {
  coredns_config = {
    chart_version = "1.43.2"
    repository    = "https://coredns.github.io/helm"
    namespace     = "kube-system"
    timeout       = 150
  }
}

# -----------------------------------------------------------------------------
# COREDNS DEPLOYMENT
# -----------------------------------------------------------------------------
# Main DNS service deployment with high availability configuration

resource "helm_release" "system_coredns" {
  name       = "coredns"
  repository = local.coredns_config.repository
  chart      = "coredns"
  version    = local.coredns_config.chart_version
  namespace  = local.coredns_config.namespace
  timeout    = local.coredns_config.timeout

  # Load CoreDNS configuration from external values file
  values = [
    file("helm_values/system_dns_config.yaml")
  ]

  # Ensure proper cleanup order
  wait            = true
  wait_for_jobs   = true
  cleanup_on_fail = true

  depends_on = [helm_release.cni_cilium]
}