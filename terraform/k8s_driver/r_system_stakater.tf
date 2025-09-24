# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# SYSTEM STAKATER RELOADER DEPLOYMENT
# =============================================================================
# Deploy Stakater Reloader for automatic pod restart on ConfigMap/Secret changes
# Ensures applications pick up configuration updates without manual intervention

# -----------------------------------------------------------------------------
# STAKATER RELOADER CONFIGURATION
# -----------------------------------------------------------------------------
# Centralized configuration for Reloader deployment

locals {
  stakater_config = {
    chart_version = "2.2.0"
    repository    = "https://stakater.github.io/stakater-charts"
    namespace     = "kube-system"
    timeout       = 150
  }
}

# -----------------------------------------------------------------------------
# STAKATER RELOADER DEPLOYMENT
# -----------------------------------------------------------------------------
# ConfigMap and Secret watcher for automated application updates

resource "helm_release" "system_stakater" {
  name       = "reloader"
  repository = local.stakater_config.repository
  chart      = "reloader"
  version    = local.stakater_config.chart_version
  namespace  = local.stakater_config.namespace
  timeout    = local.stakater_config.timeout

  # Load Reloader configuration from external values file
  values = [
    file("helm_values/system_stakater_config.yaml")
  ]

  # Ensure proper cleanup order
  wait            = true
  wait_for_jobs   = true
  cleanup_on_fail = true

  depends_on = [helm_release.cni_cilium]
}