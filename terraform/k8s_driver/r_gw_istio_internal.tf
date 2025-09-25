# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# ISTIO GATEWAY DEPLOYMENT
# =============================================================================
# Deploy Istio ingress gateways for internal network traffic management
# Provides secure ingress capabilities with service mesh integration

# -----------------------------------------------------------------------------
# ISTIO GATEWAY CONFIGURATION
# -----------------------------------------------------------------------------
# Centralized configuration for gateway components

locals {
  istio_gateway_config = {
    version    = "1.27.0"
    repository = "https://istio-release.storage.googleapis.com/charts"
    timeout    = 150
  }
}

# -----------------------------------------------------------------------------
# ISTIO INTERNAL PROXY NAMESPACE
# -----------------------------------------------------------------------------
# Dedicated namespace for internal gateway proxy with Istio injection enabled

resource "kubernetes_namespace" "istio_internal_proxy" {
  metadata {
    name = "istio-proxy-internal"
    labels = {
      "app.kubernetes.io/managed-by"               = "terraform"
      "app.kubernetes.io/component"                = "istio-gateway"
      "istio-injection"                            = "enabled"
      "pod-security.kubernetes.io/enforce"         = "baseline"
      "pod-security.kubernetes.io/enforce-version" = "latest"
    }
  }
}

# -----------------------------------------------------------------------------
# ISTIO INTERNAL INGRESS GATEWAY
# -----------------------------------------------------------------------------
# Internal network gateway for secure ingress traffic management

resource "helm_release" "istio_internal_ingressgateway" {
  name       = "istio-ingressgateway"
  repository = local.istio_gateway_config.repository
  chart      = "gateway"
  version    = local.istio_gateway_config.version
  namespace  = kubernetes_namespace.istio_internal_proxy.metadata[0].name
  timeout    = local.istio_gateway_config.timeout

  # Load gateway configuration from external values file
  values = [
    file("helm_values/gw_istio_internal_ingressgateway_config.yaml")
  ]

  # Ensure proper cleanup and recreation
  recreate_pods   = true
  cleanup_on_fail = true
  wait            = true
  wait_for_jobs   = true

  depends_on = [helm_release.istiod]
}
