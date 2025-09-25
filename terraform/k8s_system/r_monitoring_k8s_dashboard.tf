# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# KUBERNETES DASHBOARD DEPLOYMENT
# =============================================================================
# Deploy Kubernetes Dashboard with Istio integration and automated certificate management
# Provides secure web-based management interface for cluster operations

# -----------------------------------------------------------------------------
# DASHBOARD CONFIGURATION
# -----------------------------------------------------------------------------
# Centralized configuration for dashboard deployment

locals {
  dashboard_config = {
    chart_version = "7.13.0"
    repository    = "https://kubernetes.github.io/dashboard/"
    hostname      = "dashboard.low-layer.internal"
    timeout       = 150
  }
}

# -----------------------------------------------------------------------------
# MONITORING NAMESPACE
# -----------------------------------------------------------------------------
# Dedicated namespace for Kubernetes Dashboard with Istio ambient mode

resource "kubernetes_namespace" "monitoring_k8s_dashboard" {
  metadata {
    name = "monitoring-k8s-dashboard"
    labels = {
      "app.kubernetes.io/managed-by"               = "terraform"
      "app.kubernetes.io/component"                = "dashboard"
      "istio.io/dataplane-mode"                    = "ambient"
      "pod-security.kubernetes.io/enforce"         = "baseline"
      "pod-security.kubernetes.io/enforce-version" = "latest"
    }
  }
}

# -----------------------------------------------------------------------------
# DASHBOARD HELM DEPLOYMENT
# -----------------------------------------------------------------------------
# Main dashboard application with Kong proxy and TLS termination

resource "helm_release" "monitoring_k8s_dashboard" {
  name       = "dashboard-kubernetes"
  repository = local.dashboard_config.repository
  chart      = "kubernetes-dashboard"
  version    = local.dashboard_config.chart_version
  namespace  = kubernetes_namespace.monitoring_k8s_dashboard.metadata[0].name
  timeout    = local.dashboard_config.timeout

  # Load dashboard configuration from external values file
  values = [
    file("helm_values/monitoring_k8s_dashboard_config.yaml")
  ]

  # Ensure proper cleanup order
  wait          = true
  wait_for_jobs = true
  cleanup_on_fail = true
}

# -----------------------------------------------------------------------------
# TLS CERTIFICATES MANAGEMENT
# -----------------------------------------------------------------------------
# Automated certificate provisioning using Vault Secrets Operator

module "certificates_monitoring_k8s_dashboard" {
  source     = "../_modules/vso_certificates"
  namespace  = kubernetes_namespace.monitoring_k8s_dashboard.metadata[0].name
  pki_name   = "pki"
  auth_mount = "kubernetes-low-layer"
  pki_issuer = "low-layer.internal"
  pki_role   = "low-layer.internal"
  audience   = "kube.low-layer.internal"
  
  certificates = [{
    cn           = local.dashboard_config.hostname
    format       = "pem"
    ttl          = "24h"
    expiryOffset = "1h"
    secretName   = "dashboard-tls-internal"
  }]
}

# -----------------------------------------------------------------------------
# DNS CONFIGURATION
# -----------------------------------------------------------------------------
# DNS record for dashboard access via internal network

resource "unifi_dns_record" "dns_monitoring_k8s_dashboard" {
  name        = local.dashboard_config.hostname
  enabled     = true
  port        = 0
  record_type = "A"
  ttl         = 3600
  value       = data.kubernetes_service.internal_lb.status[0].load_balancer[0].ingress[0].ip
}

# -----------------------------------------------------------------------------
# ISTIO GATEWAY CONFIGURATION
# -----------------------------------------------------------------------------
# Gateway configuration for HTTPS traffic routing

resource "kubernetes_manifest" "internal_gateway_monitoring_k8s_dashboard" {
  manifest = {
    apiVersion = "networking.istio.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "k8s-dashboard-gateway"
      namespace = data.kubernetes_service.internal_lb.metadata[0].namespace
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/component"  = "istio-gateway"
      }
    }
    spec = {
      selector = {
        istio = "internal-istio-ingressgateway"
      }
      servers = [
        {
          hosts = [local.dashboard_config.hostname]
          port = {
            name     = "https"
            number   = 443
            protocol = "HTTPS"
          }
          tls = {
            mode = "PASSTHROUGH"
          }
        }
      ]
    }
  }
}

# -----------------------------------------------------------------------------
# ISTIO VIRTUAL SERVICE CONFIGURATION
# -----------------------------------------------------------------------------
# Traffic routing configuration for dashboard service

resource "kubernetes_manifest" "virtualservice_monitoring_k8s_dashboard" {
  manifest = {
    apiVersion = "networking.istio.io/v1"
    kind       = "VirtualService"
    metadata = {
      name      = "k8s-dashboard"
      namespace = kubernetes_namespace.monitoring_k8s_dashboard.metadata[0].name
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/component"  = "istio-virtualservice"
      }
    }
    spec = {
      gateways = [
        "${data.kubernetes_service.internal_lb.metadata[0].namespace}/${kubernetes_manifest.internal_gateway_monitoring_k8s_dashboard.manifest.metadata.name}"
      ]
      hosts = [local.dashboard_config.hostname]
      tls = [{
        match = [{
          port     = 443
          sniHosts = [local.dashboard_config.hostname]
        }]
        route = [{
          destination = {
            host = "dashboard-kubernetes-kong-proxy.${kubernetes_namespace.monitoring_k8s_dashboard.metadata[0].name}.svc.cluster.local"
            port = {
              number = 443
            }
          }
        }]
      }]
    }
  }
}