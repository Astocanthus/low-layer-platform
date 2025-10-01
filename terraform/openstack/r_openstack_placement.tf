# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# OPENSTACK PLACEMENT SERVICE DEPLOYMENT
# =============================================================================
# Deploy OpenStack Placement API service
# Provides resource inventory tracking and placement decision API
# Essential for OpenStack compute service (Nova) scheduling operations

# -----------------------------------------------------------------------------
# OPENSTACK PLACEMENT CONFIGURATION
# -----------------------------------------------------------------------------
# Centralized configuration for the OpenStack Placement service
# Defines key parameters for deployment, networking, and certificates

locals {
  placement_config = {
    namespace          = "openstack-placement"
    service_name       = "placement"
    domain_name        = "placement.low-layer.internal"
    internal_domain    = "placement-api.openstack-placement.svc.cluster.local"
    loadbalancer_ip    = data.kubernetes_service.internal_lb.status.0.load_balancer.0.ingress.0.ip
    deployment_timeout = "5m"
    certificate_ttl    = "24h"
    certificate_offset = "1h"
  }
}

# -----------------------------------------------------------------------------
# OPENSTACK PLACEMENT NAMESPACE
# -----------------------------------------------------------------------------
# Dedicated namespace with Istio ambient mode and security policies
# - Istio ambient mode: enables service mesh without sidecar injection
# - Pod security: baseline enforcement for workload security
# - Labels: standard Kubernetes application labels for resource management

resource "kubernetes_namespace" "openstack_placement" {
  metadata {
    name = local.placement_config.namespace
    labels = {
      "app.kubernetes.io/managed-by"               = "terraform"
      "app.kubernetes.io/component"                = "api"
      "app.kubernetes.io/part-of"                  = "openstack-placement"
      "istio.io/dataplane-mode"                    = "ambient"
      "pod-security.kubernetes.io/enforce"         = "baseline"
      "pod-security.kubernetes.io/enforce-version" = "latest"
    }
  }
}

# -----------------------------------------------------------------------------
# OPENSTACK PLACEMENT DEPLOYMENT
# -----------------------------------------------------------------------------
# Deploys Placement API service using reusable module
# Dependencies include Keystone, RabbitMQ, Memcached, MariaDB
# Ensures Keystone authentication is configured prior to deployment

module "openstack_placement" {
  source                   = "../_modules/os_placement"
  namespace                = kubernetes_namespace.openstack_placement.metadata[0].name
  infrastructure_namespace = kubernetes_namespace.openstack_infrastructure.metadata[0].name
  keystone_namespace       = kubernetes_namespace.openstack_keystone.metadata[0].name
  timeout                  = local.placement_config.deployment_timeout

  depends_on = [
    helm_release.openstack_mariadb,
    helm_release.openstack_rabbitmq,
    helm_release.openstack_memcached,
    module.openstack_keystone
  ]
}

# -----------------------------------------------------------------------------
# TLS CERTIFICATES - EXTERNAL ACCESS
# -----------------------------------------------------------------------------
# Public-facing certificates for external service access
# Uses Vault PKI to automatically issue and renew certificates

module "certificates_openstack_placement" {
  source     = "../_modules/vso_certificates"
  namespace  = kubernetes_namespace.openstack_placement.metadata[0].name
  pki_name   = "pki"
  auth_mount = "kubernetes-low-layer"
  pki_issuer = "low-layer.internal"
  pki_role   = "low-layer.internal"
  audience   = "kube.low-layer.internal"

  certificates = [{
    cn           = local.placement_config.domain_name
    format       = "pem"
    ttl          = local.placement_config.certificate_ttl
    expiryOffset = local.placement_config.certificate_offset
    secretName   = "placement-tls-internal"
  }]
}

# -----------------------------------------------------------------------------
# TLS CERTIFICATES - INTERNAL COMMUNICATION (OPTIONAL)
# -----------------------------------------------------------------------------
# Inter-service communication certificate for service mesh traffic
# Cluster-local PKI backend issues mTLS trust chain

module "certificates_openstack_placement_internal" {
  source     = "../_modules/vso_certificates"
  namespace  = kubernetes_namespace.openstack_placement.metadata[0].name
  pki_name   = "pki-kubernetes"
  auth_mount = "kubernetes-low-layer"
  pki_issuer = "low-layer.local"
  pki_role   = "low-layer.local"
  audience   = "kube.low-layer.internal"

  certificates = [{
    cn           = local.placement_config.internal_domain
    format       = "pem"
    ttl          = local.placement_config.certificate_ttl
    expiryOffset = local.placement_config.certificate_offset
    secretName   = "placement-tls-local"
  }]
}

# -----------------------------------------------------------------------------
# DNS CONFIGURATION
# -----------------------------------------------------------------------------
# DNS resolution for accessing Placement API via internal domain
# Resolves to internal load balancer IP with 1-hour TTL for availability

resource "unifi_dns_record" "dns_service" {
  name        = local.placement_config.domain_name
  enabled     = true
  port        = 0
  record_type = "A"
  ttl         = 3600
  value       = local.placement_config.loadbalancer_ip
}

# -----------------------------------------------------------------------------
# ISTIO GATEWAY CONFIGURATION
# -----------------------------------------------------------------------------
# Enables inbound TLS traffic via encrypted passthrough method
# Gateway delegates TLS termination to Placement API for end-to-end security

resource "kubernetes_manifest" "internal_gateway_service" {
  manifest = {
    apiVersion = "networking.istio.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "openstack-placement-gateway"
      namespace = data.kubernetes_service.internal_lb.metadata[0].namespace
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/component"  = "istio-gateway"
        "app.kubernetes.io/part-of"    = "openstack-placement"
      }
    }
    spec = {
      selector = {
        istio = "internal-istio-ingressgateway"
      }
      servers = [{
        hosts = [
          local.placement_config.domain_name
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
# Routes TLS traffic received by gateway to Placement API backend
# Matches on SNI host and preserves encrypted transport end-to-end

resource "kubernetes_manifest" "virtualservice_service" {
  manifest = {
    apiVersion = "networking.istio.io/v1"
    kind       = "VirtualService"
    metadata = {
      name      = "openstack-placement"
      namespace = kubernetes_namespace.openstack_placement.metadata[0].name
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/component"  = "istio-routing"
        "app.kubernetes.io/part-of"    = "openstack-placement"
      }
    }
    spec = {
      gateways = [
        "${data.kubernetes_service.internal_lb.metadata[0].namespace}/${kubernetes_manifest.internal_gateway_service.manifest.metadata.name}"
      ]
      hosts = [
        local.placement_config.domain_name
      ]
      tls = [ {
        match = [ {
          port     = 443
          sniHosts = [
            local.placement_config.domain_name
          ]
        } ]
        route = [ {
          destination = {
            host = local.placement_config.internal_domain
            port = {
              number = 443
            }
          }
        } ]
      } ]
    }
  }
}