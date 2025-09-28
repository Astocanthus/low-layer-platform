# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# OPENSTACK GLANCE IMAGE SERVICE DEPLOYMENT
# =============================================================================
# Deploy OpenStack Glance image management service with TLS certificates and routing
# Provides virtual machine image storage and management for OpenStack compute instances

# -----------------------------------------------------------------------------
# GLANCE SERVICE CONFIGURATION
# -----------------------------------------------------------------------------
# Centralized configuration for Glance image service

locals {
  glance_config = {
    namespace          = "openstack-glance"
    service_name       = "image"
    domain_name        = "image.low-layer.internal"
    internal_domain    = "image-api.openstack-glance.svc.cluster.local"
    loadbalancer_ip    = data.kubernetes_service.internal_lb.status.0.load_balancer.0.ingress.0.ip
    deployment_timeout = "5m"
    certificate_ttl    = "24h"
    certificate_offset = "1h"
  }
}

# -----------------------------------------------------------------------------
# GLANCE NAMESPACE
# -----------------------------------------------------------------------------
# Dedicated namespace with Istio ambient mode and security policies

resource "kubernetes_namespace" "openstack_glance" {
  metadata {
    name = local.glance_config.namespace
    labels = {
      "app.kubernetes.io/managed-by"               = "terraform"
      "app.kubernetes.io/component"                = "openstack-glance"
      "app.kubernetes.io/part-of"                  = "openstack"
      "istio.io/dataplane-mode"                    = "ambient"
      "pod-security.kubernetes.io/enforce"         = "baseline"
      "pod-security.kubernetes.io/enforce-version" = "latest"
    }
  }
}

# -----------------------------------------------------------------------------
# GLANCE SERVICE DEPLOYMENT
# -----------------------------------------------------------------------------
# Image management service with dependency management

module "openstack_glance" {
  source                   = "../_modules/os_glance"
  namespace                = kubernetes_namespace.openstack_glance.metadata[0].name
  infrastructure_namespace = kubernetes_namespace.openstack_infrastructure.metadata[0].name
  keystone_namespace       = kubernetes_namespace.openstack_keystone.metadata[0].name
  timeout                  = local.glance_config.deployment_timeout

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
# Public-facing certificates for external API access

module "certificates_openstack_glance" {
  source     = "../_modules/vso_certificates"
  namespace  = kubernetes_namespace.openstack_glance.metadata[0].name
  pki_name   = "pki"
  auth_mount = "kubernetes-low-layer"
  pki_issuer = "low-layer.internal"
  pki_role   = "low-layer.internal"
  audience   = "kube.low-layer.internal"

  certificates = [{
    cn           = local.glance_config.domain_name
    format       = "pem"
    ttl          = local.glance_config.certificate_ttl
    expiryOffset = local.glance_config.certificate_offset
    secretName   = "glance-tls-internal"
  }]
}

# -----------------------------------------------------------------------------
# TLS CERTIFICATES - INTERNAL COMMUNICATION
# -----------------------------------------------------------------------------
# Service mesh certificates for inter-service communication

module "certificates_openstack_glance_internal" {
  source     = "../_modules/vso_certificates"
  namespace  = kubernetes_namespace.openstack_glance.metadata[0].name
  pki_name   = "pki-kubernetes"
  auth_mount = "kubernetes-low-layer"
  pki_issuer = "low-layer.local"
  pki_role   = "low-layer.local"
  audience   = "kube.low-layer.internal"

  certificates = [{
    cn           = local.glance_config.internal_domain
    format       = "pem"
    ttl          = local.glance_config.certificate_ttl
    expiryOffset = local.glance_config.certificate_offset
    secretName   = "glance-tls-local"
  }]
}

# -----------------------------------------------------------------------------
# DNS CONFIGURATION
# -----------------------------------------------------------------------------
# UniFi DNS record for Glance API endpoint resolution

resource "unifi_dns_record" "dns_openstack_glance" {
  name        = local.glance_config.domain_name
  enabled     = true
  port        = 0
  record_type = "A"
  ttl         = 3600
  value       = local.glance_config.loadbalancer_ip
}

# -----------------------------------------------------------------------------
# ISTIO GATEWAY CONFIGURATION
# -----------------------------------------------------------------------------
# HTTPS gateway with TLS passthrough for secure API access

resource "kubernetes_manifest" "internal_gateway_openstack_glance" {
  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "Gateway"
    metadata = {
      name      = "openstack-glance-gateway"
      namespace = data.kubernetes_service.internal_lb.metadata[0].namespace
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/component"  = "istio-gateway"
        "app.kubernetes.io/part-of"    = "openstack-glance"
      }
    }
    spec = {
      selector = {
        istio = "internal-istio-ingressgateway"
      }
      servers = [{
        hosts = [
          local.glance_config.domain_name
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
# TLS traffic routing from gateway to Glance API service

resource "kubernetes_manifest" "virtualservice_openstack_glance" {
  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "VirtualService"
    metadata = {
      name      = "openstack-glance"
      namespace = kubernetes_namespace.openstack_glance.metadata[0].name
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/component"  = "istio-routing"
        "app.kubernetes.io/part-of"    = "openstack-glance"
      }
    }
    spec = {
      gateways = [
        "${data.kubernetes_service.internal_lb.metadata[0].namespace}/${kubernetes_manifest.internal_gateway_openstack_glance.manifest.metadata.name}"
      ]
      hosts = [
        local.glance_config.domain_name
      ]
      tls = [{
        match = [{
          port     = 443
          sniHosts = [
            local.glance_config.domain_name
          ]
        }]
        route = [{
          destination = {
            host = local.glance_config.internal_domain
            port = {
              number = 443
            }
          }
        }]
      }]
    }
  }
}