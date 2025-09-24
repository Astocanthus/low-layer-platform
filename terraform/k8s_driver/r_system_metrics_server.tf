# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# SYSTEM METRICS SERVER DEPLOYMENT
# =============================================================================
# Deploy Kubernetes Metrics Server for resource usage metrics collection
# Enables Horizontal Pod Autoscaler and kubectl top commands

# -----------------------------------------------------------------------------
# METRICS SERVER CONFIGURATION
# -----------------------------------------------------------------------------
# Centralized configuration for Metrics Server deployment

locals {
  metrics_server_config = {
    chart_version = "3.13.0"
    repository    = "https://kubernetes-sigs.github.io/metrics-server/"
    namespace     = "kube-system"
    timeout       = 150
  }
}

# -----------------------------------------------------------------------------
# METRICS SERVER DEPLOYMENT
# -----------------------------------------------------------------------------
# Core metrics collection service for cluster resource monitoring

resource "helm_release" "system_metrics_server" {
  name       = "metrics-server"
  repository = local.metrics_server_config.repository
  chart      = "metrics-server"
  version    = local.metrics_server_config.chart_version
  namespace  = local.metrics_server_config.namespace
  timeout    = local.metrics_server_config.timeout

  # Load Metrics Server configuration from external values file
  values = [
    file("helm_values/system_metrics_server_config.yaml")
  ]

  # Ensure proper cleanup order
  wait            = true
  wait_for_jobs   = true
  cleanup_on_fail = true

  depends_on = [helm_release.cni_cilium]
}