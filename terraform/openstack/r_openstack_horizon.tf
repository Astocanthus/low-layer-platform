# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# OPENSTACK HORIZON DASHBOARD SERVICE DEPLOYMENT
# =============================================================================
# Deploy OpenStack Horizon web dashboard with TLS certificates and routing
# Provides web-based management interface for OpenStack cloud resources

# -----------------------------------------------------------------------------
# HORIZON SERVICE CONFIGURATION
# -----------------------------------------------------------------------------
# Centralized configuration for Horizon dashboard service

locals {
  horizon_config = {
    namespace         = "openstack-horizon"
    service_name      = "horizon"
    domain_name       = "horizon.low-layer.internal"
    internal_domain   = "horizon-web.openstack-horizon.svc.cluster.local"
    loadbalancer_ip   = data.kubernetes_service.internal_lb.status.0.load_balancer.0.ingress.0.ip
    deployment_timeout = "5m"
    certificate_ttl    = "24h"
    certificate_offset = "1h"
    ca_secret_name     = "horizon-tls-local"
  }
}

# -----------------------------------------------------------------------------
# HORIZON NAMESPACE
# -----------------------------------------------------------------------------
# Dedicated namespace with Istio ambient mode and security policies

resource "kubernetes_namespace" "openstack_horizon" {
  metadata {
    name = local.horizon_config.namespace
    labels = {
      "app.kubernetes.io/managed-by"               = "terraform"
      "app.kubernetes.io/component"                = "openstack-horizon"
      "app.kubernetes.io/part-of"                  = "openstack"
      "istio.io/dataplane-mode"                    = "ambient"
      "pod-security.kubernetes.io/enforce"         = "baseline"
      "pod-security.kubernetes.io/enforce-version" = "latest"
    }
  }
}

# -----------------------------------------------------------------------------
# LOCAL CA CERTIFICATE SECRET
# -----------------------------------------------------------------------------
# Certificate Authority secret for internal certificate validation

resource "kubernetes_secret" "horizon_tls_local" {
  metadata {
    name      = local.horizon_config.ca_secret_name
    namespace = kubernetes_namespace.openstack_horizon.metadata[0].name
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "tls-certificate"
      "app.kubernetes.io/part-of"    = "openstack-horizon"
    }
  }

  data = {
    issuing_ca = data.vault_pki_secret_backend_issuer.local_ca.certificate
  }

  type = "Opaque"
}

# -----------------------------------------------------------------------------
# HORIZON SERVICE DEPLOYMENT
# -----------------------------------------------------------------------------
# Web dashboard service with dependency management

module "openstack_horizon" {
  source                   = "../_modules/os_horizon"
  namespace                = kubernetes_namespace.openstack_horizon.metadata[0].name
  infrastructure_namespace = kubernetes_namespace.openstack_infrastructure.metadata[0].name
  keystone_namespace       = kubernetes_namespace.openstack_keystone.metadata[0].name
  local_ca_secret_name     = kubernetes_secret.horizon_tls_local.metadata[0].name
  timeout                  = local.horizon_config.deployment_timeout

  depends_on = [
    helm_release.openstack_mariadb,
    helm_release.openstack_rabbitmq,
    helm_release.openstack_memcached
  ]
}

# -----------------------------------------------------------------------------
# TLS CERTIFICATES - EXTERNAL ACCESS
# -----------------------------------------------------------------------------
# Public-facing certificates for external dashboard access

module "certificates_openstack_horizon" {
  source     = "../_modules/vso_certificates"
  namespace  = kubernetes_namespace.openstack_horizon.metadata[0].name
  pki_name   = "pki"
  auth_mount = "kubernetes-low-layer"
  pki_issuer = "low-layer.internal"
  pki_role   = "low-layer.internal"
  audience   = "kube.low-layer.internal"

  certificates = [{
    cn           = local.horizon_config.domain_name
    format       = "pem"
    ttl          = local.horizon_config.certificate_ttl
    expiryOffset = local.horizon_config.certificate_offset
    secretName   = "horizon-tls-internal"
  }]
}

# -----------------------------------------------------------------------------
# DNS CONFIGURATION
# -----------------------------------------------------------------------------
# UniFi DNS record for Horizon dashboard endpoint resolution

resource "unifi_dns_record" "dns_openstack_horizon" {
  name        = local.horizon_config.domain_name
  enabled     = true
  port        = 0
  record_type = "A"
  ttl         = 3600
  value       = local.horizon_config.loadbalancer_ip
}

# -----------------------------------------------------------------------------
# ISTIO GATEWAY CONFIGURATION
# -----------------------------------------------------------------------------
# HTTPS gateway with TLS passthrough for secure dashboard access

resource "kubernetes_manifest" "internal_gateway_openstack_horizon" {
  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "Gateway"
    metadata = {
      name      = "openstack-horizon-gateway"
      namespace = data.kubernetes_service.internal_lb.metadata[0].namespace
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/component"  = "istio-gateway"
        "app.kubernetes.io/part-of"    = "openstack-horizon"
      }
    }
    spec = {
      selector = {
        istio = "internal-istio-ingressgateway"
      }
      servers = [{
        hosts = [
          local.horizon_config.domain_name
        ]
        port = {
          name     = "https"
          number   = 443
          protocol = "HTTPS"
        }
        tls = {
          mode = "PASSTHROUGH"
        }
      }]
    }
  }
}

# -----------------------------------------------------------------------------
# ISTIO VIRTUAL SERVICE
# -----------------------------------------------------------------------------
# TLS traffic routing from gateway to Horizon dashboard service

resource "kubernetes_manifest" "virtualservice_openstack_horizon" {
  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "VirtualService"
    metadata = {
      name      = "openstack-horizon"
      namespace = kubernetes_namespace.openstack_horizon.metadata[0].name
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/component"  = "istio-routing"
        "app.kubernetes.io/part-of"    = "openstack-horizon"
      }
    }
    spec = {
      gateways = [
        "${data.kubernetes_service.internal_lb.metadata[0].namespace}/${kubernetes_manifest.internal_gateway_openstack_horizon.manifest.metadata.name}"
      ]
      hosts = [
        local.horizon_config.domain_name
      ]
      tls = [{
        match = [{
          port     = 443
          sniHosts = [
            local.horizon_config.domain_name
          ]
        }]
        route = [{
          destination = {
            host = local.horizon_config.internal_domain
            port = {
              number = 443
            }
          }
        }]
      }]
    }
  }
}