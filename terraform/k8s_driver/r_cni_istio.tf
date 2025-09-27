# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# ISTIO CNI DEPLOYMENT
# =============================================================================
# Deploy Istio service mesh with Ambient mode for advanced traffic management
# and security features integrated with Cilium CNI

# -----------------------------------------------------------------------------
# ISTIO CONFIGURATION
# -----------------------------------------------------------------------------
# Centralized configuration for Istio components deployment

locals {
  istio_config = {
    version    = "1.27.0"
    repository = "https://istio-release.storage.googleapis.com/charts"
    timeout    = 150
  }
}

# -----------------------------------------------------------------------------
# ISTIO SYSTEM NAMESPACE
# -----------------------------------------------------------------------------
# Dedicated namespace for Istio control plane components with security policies

resource "kubernetes_namespace" "istio_system" {
  metadata {
    name = "istio-system"
    labels = {
      "app.kubernetes.io/managed-by"               = "terraform"
      "app.kubernetes.io/component"                = "istio-system"
      "pod-security.kubernetes.io/enforce"         = "privileged"
      "pod-security.kubernetes.io/enforce-version" = "latest"
    }
  }
} 

# -----------------------------------------------------------------------------
# ISTIO BASE COMPONENTS
# -----------------------------------------------------------------------------
# Foundational Istio components including CRDs and cluster-wide resources

resource "helm_release" "istio_base" {
  name       = "base"
  repository = local.istio_config.repository
  chart      = "base"
  version    = local.istio_config.version
  namespace  = kubernetes_namespace.istio_system.metadata[0].name
  timeout    = local.istio_config.timeout

  # Ensure proper cleanup order
  wait            = true
  wait_for_jobs   = true
  cleanup_on_fail = true

  depends_on = [helm_release.cni_cilium]
}

# -----------------------------------------------------------------------------
# GLOBAL MTLS POLICY
# -----------------------------------------------------------------------------
# Enforce strict mutual TLS across the entire mesh for security

resource "kubectl_manifest" "istio_global_mtls" {
  yaml_body = yamlencode({
    apiVersion = "security.istio.io/v1"
    kind       = "PeerAuthentication"
    metadata = {
      name      = "global-mtls"
      namespace = kubernetes_namespace.istio_system.metadata[0].name
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/component"  = "istio-security"
      }
    }
    spec = {
      mtls = {
        mode = "STRICT"
      }
    }
  })

  depends_on = [helm_release.istio_base]
}

# -----------------------------------------------------------------------------
# ISTIO CONTROL PLANE (ISTIOD)
# -----------------------------------------------------------------------------
# Main control plane component managing configuration and certificates

resource "helm_release" "istiod" {
  name       = "istiod"
  repository = local.istio_config.repository
  chart      = "istiod"
  version    = local.istio_config.version
  namespace  = kubernetes_namespace.istio_system.metadata[0].name
  timeout    = local.istio_config.timeout

  # Load Istiod configuration from external values file
  values = [
    file("helm_values/cni_istiod_config.yaml")
  ]

  # Ensure proper cleanup order
  wait            = true
  wait_for_jobs   = true
  cleanup_on_fail = true

  depends_on = [helm_release.istio_base]
}

# -----------------------------------------------------------------------------
# ISTIO CNI PLUGIN
# -----------------------------------------------------------------------------
# CNI plugin for transparent traffic interception in ambient mode

resource "helm_release" "istio_cni" {
  name       = "cni"
  repository = local.istio_config.repository
  chart      = "cni"
  version    = local.istio_config.version
  namespace  = "kube-system"
  timeout    = local.istio_config.timeout

  # Load CNI configuration from external values file
  values = [
    file("helm_values/cni_istio_cni_config.yaml")
  ]

  # Ensure proper cleanup order
  wait            = true
  wait_for_jobs   = true
  cleanup_on_fail = true
  
  depends_on = [helm_release.istio_base]
}

# -----------------------------------------------------------------------------
# ISTIO ZTUNNEL (AMBIENT MODE)
# -----------------------------------------------------------------------------
# Zero-trust tunnel component for ambient mesh data plane

resource "helm_release" "istio_ztunnel" {
  name       = "ztunnel"
  repository = local.istio_config.repository
  chart      = "ztunnel"
  version    = local.istio_config.version
  namespace  = kubernetes_namespace.istio_system.metadata[0].name
  timeout    = local.istio_config.timeout

  # Load ztunnel configuration from external values file
  values = [
    file("helm_values/cni_istio_ztunnel_config.yaml")
  ]

  # Ensure proper cleanup order
  wait            = true
  wait_for_jobs   = true
  cleanup_on_fail = true

  depends_on = [helm_release.istio_base]
}