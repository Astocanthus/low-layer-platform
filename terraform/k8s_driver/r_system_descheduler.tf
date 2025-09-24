# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# SYSTEM DESCHEDULER DEPLOYMENT
# =============================================================================
# Deploy Kubernetes Descheduler for automated pod eviction and rebalancing
# Optimizes cluster resource utilization and workload distribution

# -----------------------------------------------------------------------------
# DESCHEDULER CONFIGURATION
# -----------------------------------------------------------------------------
# Centralized configuration for descheduler deployment

locals {
  descheduler_config = {
    chart_version = "0.33.0"
    repository    = "https://kubernetes-sigs.github.io/descheduler/"
    namespace     = "kube-system"
    timeout       = 150
  }
}

# -----------------------------------------------------------------------------
# DESCHEDULER DEPLOYMENT
# -----------------------------------------------------------------------------
# Main descheduler component for cluster workload optimization

resource "helm_release" "system_descheduler" {
  name       = "descheduler"
  repository = local.descheduler_config.repository
  chart      = "descheduler"
  version    = local.descheduler_config.chart_version
  namespace  = local.descheduler_config.namespace
  timeout    = local.descheduler_config.timeout

  # Load descheduler configuration from external values file
  values = [
    file("helm_values/system_descheduler_config.yaml")
  ]

  # Ensure proper cleanup order
  wait            = true
  wait_for_jobs   = true
  cleanup_on_fail = true
}