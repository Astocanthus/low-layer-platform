# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# OPENSTACK KEYSTONE IDENTITY SERVICE DEPLOYMENT
# =============================================================================
# Deploy OpenStack Keystone identity and authentication service with TLS certificates
# Provides centralized authentication, authorization and service catalog for OpenStack

# -----------------------------------------------------------------------------
# KEYSTONE SERVICE CONFIGURATION
# -----------------------------------------------------------------------------
# Centralized configuration for Keystone identity service

locals {
  keystone_config = {
    namespace         = "openstack-keystone"
    service_name      = "keystone"
    domain_name       = "keystone.low-layer.internal"
    internal_domain   = "keystone-api.openstack-keystone.svc.cluster.local"
    loadbalancer_ip   = data.kubernetes_service.internal_lb.status.0.load_balancer.0.ingress.0.ip
    deployment_timeout = "5m"
    certificate_ttl    = "24h"
    certificate_offset = "1h"
  }
}

# -----------------------------------------------------------------------------
# KEYSTONE NAMESPACE
# -----------------------------------------------------------------------------
# Dedicated namespace with Istio ambient mode and security policies

resource "kubernetes_namespace" "openstack_keystone" {
  metadata {
    name = local.keystone_config.namespace
    labels = {
      "app.kubernetes.io/managed-by"               = "terraform"
      "app.kubernetes.io/component"                = "openstack-keystone"
      "app.kubernetes.io/part-of"                  = "openstack"
      "istio.io/dataplane-mode"                    = "ambient"
      "pod-security.kubernetes.io/enforce"         = "baseline"
      "pod-security.kubernetes.io/enforce-version" = "latest"
    }
  }
}

# -----------------------------------------------------------------------------
# KEYSTONE SERVICE DEPLOYMENT
# -----------------------------------------------------------------------------
# Identity and authentication service with dependency management

module "openstack_keystone" {
  source                   = "../_modules/os_keystone"
  namespace                = kubernetes_namespace.openstack_keystone.metadata[0].name
  infrastructure_namespace = kubernetes_namespace.openstack_infrastructure.metadata[0].name
  timeout                  = local.keystone_config.deployment_timeout

  depends_on = [
    helm_release.openstack_mariadb,
    helm_release.openstack_rabbitmq,
    helm_release.openstack_memcached
  ]
}

# -----------------------------------------------------------------------------
# TLS CERTIFICATES - EXTERNAL ACCESS
# -----------------------------------------------------------------------------
# Public-facing certificates for external API access

module "certificates_openstack_keystone_admin" {
  source     = "../_modules/vso_certificates"
  namespace  = kubernetes_namespace.openstack_keystone.metadata[0].name
  pki_name   = "pki"
  auth_mount = "kubernetes-low-layer"
  pki_issuer = "low-layer.internal"
  pki_role   = "low-layer.internal"
  audience   = "kube.low-layer.internal"

  certificates = [{
    cn           = local.keystone_config.domain_name
    format       = "pem"
    ttl          = local.keystone_config.certificate_ttl
    expiryOffset = local.keystone_config.certificate_offset
    secretName   = "keystone-tls-internal"
  }]
}

# -----------------------------------------------------------------------------
# TLS CERTIFICATES - INTERNAL COMMUNICATION
# -----------------------------------------------------------------------------
# Service mesh certificates for inter-service communication

module "certificates_openstack_keystone_internal" {
  source     = "../_modules/vso_certificates"
  namespace  = kubernetes_namespace.openstack_keystone.metadata[0].name
  pki_name   = "pki-kubernetes"
  auth_mount = "kubernetes-low-layer"
  pki_issuer = "low-layer.local"
  pki_role   = "low-layer.local"
  audience   = "kube.low-layer.internal"

  certificates = [{
    cn           = local.keystone_config.internal_domain
    format       = "pem"
    ttl          = local.keystone_config.certificate_ttl
    expiryOffset = local.keystone_config.certificate_offset
    secretName   = "keystone-tls-local"
  }]
}

# -----------------------------------------------------------------------------
# DNS CONFIGURATION
# -----------------------------------------------------------------------------
# UniFi DNS record for Keystone API endpoint resolution

resource "unifi_dns_record" "dns_openstack_keystone" {
  name        = local.keystone_config.domain_name
  enabled     = true
  port        = 0
  record_type = "A"
  ttl         = 3600
  value       = local.keystone_config.loadbalancer_ip
}

# -----------------------------------------------------------------------------
# ISTIO GATEWAY CONFIGURATION
# -----------------------------------------------------------------------------
# HTTPS gateway with TLS passthrough for secure API access

resource "kubernetes_manifest" "internal_gateway_openstack_keystone" {
  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "Gateway"
    metadata = {
      name      = "openstack-keystone-gateway"
      namespace = data.kubernetes_service.internal_lb.metadata[0].namespace
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/component"  = "istio-gateway"
        "app.kubernetes.io/part-of"    = "openstack-keystone"
      }
    }
    spec = {
      selector = {
        istio = "internal-istio-ingressgateway"
      }
      servers = [{
        hosts = [
          local.keystone_config.domain_name
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
# TLS traffic routing from gateway to Keystone API service

resource "kubernetes_manifest" "virtualservice_openstack_keystone" {
  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "VirtualService"
    metadata = {
      name      = "openstack-keystone"
      namespace = kubernetes_namespace.openstack_keystone.metadata[0].name
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/component"  = "istio-routing"
        "app.kubernetes.io/part-of"    = "openstack-keystone"
      }
    }
    spec = {
      gateways = [
        "${data.kubernetes_service.internal_lb.metadata[0].namespace}/${kubernetes_manifest.internal_gateway_openstack_keystone.manifest.metadata.name}"
      ]
      hosts = [
        local.keystone_config.domain_name
      ]
      tls = [{
        match = [{
          port     = 443
          sniHosts = [
            local.keystone_config.domain_name
          ]
        }]
        route = [{
          destination = {
            host = local.keystone_config.internal_domain
            port = {
              number = 443
            }
          }
        }]
      }]
    }
  }
}