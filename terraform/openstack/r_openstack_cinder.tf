# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# OPENSTACK CINDER VOLUME SERVICE DEPLOYMENT
# =============================================================================
# Deploy OpenStack Cinder block storage service with TLS certificates and routing
# Provides persistent volume management for OpenStack compute instances

# -----------------------------------------------------------------------------
# CINDER SERVICE CONFIGURATION
# -----------------------------------------------------------------------------
# Centralized configuration for Cinder volume service

locals {
  cinder_config = {
    namespace          = "openstack-cinder"
    service_name       = "volume"
    domain_name        = "volume.low-layer.internal"
    internal_domain    = "volume-api.openstack-cinder.svc.cluster.local"
    loadbalancer_ip    = data.kubernetes_service.internal_lb.status.0.load_balancer.0.ingress.0.ip
    deployment_timeout = "5m"
    certificate_ttl    = "24h"
    certificate_offset = "1h"
  }
}

# -----------------------------------------------------------------------------
# CINDER NAMESPACE
# -----------------------------------------------------------------------------
# Dedicated namespace with Istio ambient mode and security policies

resource "kubernetes_namespace" "openstack_cinder" {
  metadata {
    name = local.cinder_config.namespace
    labels = {
      "app.kubernetes.io/managed-by"               = "terraform"
      "app.kubernetes.io/component"                = "openstack-cinder"
      "app.kubernetes.io/part-of"                  = "openstack"
      "istio.io/dataplane-mode"                    = "ambient"
      "pod-security.kubernetes.io/enforce"         = "baseline"
      "pod-security.kubernetes.io/enforce-version" = "latest"
    }
  }
}

# -----------------------------------------------------------------------------
# CINDER SERVICE DEPLOYMENT
# -----------------------------------------------------------------------------
# Block storage service with dependency management

module "openstack_cinder" {
  source                   = "../_modules/os_cinder"
  namespace                = kubernetes_namespace.openstack_cinder.metadata[0].name
  infrastructure_namespace = kubernetes_namespace.openstack_infrastructure.metadata[0].name
  keystone_namespace       = kubernetes_namespace.openstack_keystone.metadata[0].name
  timeout                  = local.cinder_config.deployment_timeout

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

module "certificates_openstack_cinder" {
  source     = "../_modules/vso_certificates"
  namespace  = kubernetes_namespace.openstack_cinder.metadata[0].name
  pki_name   = "pki"
  auth_mount = "kubernetes-low-layer"
  pki_issuer = "low-layer.internal"
  pki_role   = "low-layer.internal"
  audience   = "kube.low-layer.internal"

  certificates = [{
    cn           = local.cinder_config.domain_name
    format       = "pem"
    ttl          = local.cinder_config.certificate_ttl
    expiryOffset = local.cinder_config.certificate_offset
    secretName   = "cinder-tls-internal"
  }]
}

# -----------------------------------------------------------------------------
# TLS CERTIFICATES - INTERNAL COMMUNICATION
# -----------------------------------------------------------------------------
# Service mesh certificates for inter-service communication

module "certificates_openstack_cinder_internal" {
  source     = "../_modules/vso_certificates"
  namespace  = kubernetes_namespace.openstack_cinder.metadata[0].name
  pki_name   = "pki-kubernetes"
  auth_mount = "kubernetes-low-layer"
  pki_issuer = "low-layer.local"
  pki_role   = "low-layer.local"
  audience   = "kube.low-layer.internal"

  certificates = [{
    cn           = local.cinder_config.internal_domain
    format       = "pem"
    ttl          = local.cinder_config.certificate_ttl
    expiryOffset = local.cinder_config.certificate_offset
    secretName   = "cinder-tls-local"
  }]
}

# -----------------------------------------------------------------------------
# DNS CONFIGURATION
# -----------------------------------------------------------------------------
# UniFi DNS record for Cinder API endpoint resolution

resource "unifi_dns_record" "dns_openstack_cinder" {
  name        = local.cinder_config.domain_name
  enabled     = true
  port        = 0
  record_type = "A"
  ttl         = 3600
  value       = local.cinder_config.loadbalancer_ip

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# ISTIO GATEWAY CONFIGURATION
# -----------------------------------------------------------------------------
# HTTPS gateway with TLS passthrough for secure API access

resource "kubernetes_manifest" "internal_gateway_openstack_cinder" {
  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "Gateway"
    metadata = {
      name      = "openstack-cinder-gateway"
      namespace = data.kubernetes_service.internal_lb.metadata[0].namespace
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/component"  = "istio-gateway"
        "app.kubernetes.io/part-of"    = "openstack-cinder"
      }
    }
    spec = {
      selector = {
        istio = "internal-istio-ingressgateway"
      }
      servers = [{
        hosts = [
          local.cinder_config.domain_name
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
# TLS traffic routing from gateway to Cinder API service

resource "kubernetes_manifest" "virtualservice_openstack_cinder" {
  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "VirtualService"
    metadata = {
      name      = "openstack-cinder"
      namespace = kubernetes_namespace.openstack_cinder.metadata[0].name
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/component"  = "istio-routing"
        "app.kubernetes.io/part-of"    = "openstack-cinder"
      }
    }
    spec = {
      gateways = [
        "${data.kubernetes_service.internal_lb.metadata[0].namespace}/${kubernetes_manifest.internal_gateway_openstack_cinder.manifest.metadata.name}"
      ]
      hosts = [
        local.cinder_config.domain_name
      ]
      tls = [{
        match = [{
          port     = 443
          sniHosts = [
            local.cinder_config.domain_name
          ]
        }]
        route = [{
          destination = {
            host = local.cinder_config.internal_domain
            port = {
              number = 443
            }
          }
        }]
      }]
    }
  }
}