# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# TEST DEPLOYMENT
# =============================================================================
# Deploy test application with NGINX, TLS certificates, and Istio routing
# Demonstrates full stack integration: storage, networking, security, and service mesh

# -----------------------------------------------------------------------------
# TEST DEPLOYMENT CONFIGURATION
# -----------------------------------------------------------------------------
# Centralized configuration for test environment

locals {
  test_config = {
    namespace   = "test"
    app_name    = "nginx"
    domain_name = "test.low-layer.internal"
    storage_size = "10Gi"
    storage_class = "synology-iscsi-ssd"
    loadbalancer_ip = "192.168.3.150"
  }
}

# -----------------------------------------------------------------------------
# TEST NAMESPACE
# -----------------------------------------------------------------------------
# Dedicated namespace with Istio ambient mode and security policies

resource "kubernetes_namespace" "test" {
  metadata {
    name = local.test_config.namespace
    labels = {
      "app.kubernetes.io/managed-by"             = "terraform"
      "app.kubernetes.io/component"              = "test-environment"
      "istio.io/dataplane-mode"                 = "ambient"
      "pod-security.kubernetes.io/enforce"       = "baseline"
      "pod-security.kubernetes.io/enforce-version" = "latest"
    }
  }
}

# -----------------------------------------------------------------------------
# NGINX CONFIGURATION
# -----------------------------------------------------------------------------
# ConfigMap containing NGINX SSL configuration

resource "kubernetes_config_map" "nginx_conf" {
  metadata {
    name      = "nginx-conf"
    namespace = kubernetes_namespace.test.metadata[0].name
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "nginx-config"
      "app.kubernetes.io/part-of"    = local.test_config.app_name
    }
  }

  data = {
    "nginx.conf" = <<-EOF
      events {}
      http {
          server {
              listen 443 ssl;
              ssl_certificate     /vault/secrets/certificate;
              ssl_certificate_key /vault/secrets/private_key;

              location / {
                  return 200 'Hello TLS!';
              }
          }
      }
    EOF
  }
}

# -----------------------------------------------------------------------------
# NGINX STATEFULSET DEPLOYMENT
# -----------------------------------------------------------------------------
# StatefulSet with persistent storage and automatic certificate integration

resource "kubernetes_stateful_set" "nginx" {
  metadata {
    name      = "nginx-test"
    namespace = kubernetes_namespace.test.metadata[0].name
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "web-server"
      "app.kubernetes.io/part-of"    = local.test_config.app_name
      app = local.test_config.app_name
    }
    annotations = {
      "reloader.stakater.com/auto" = "true"
    }
  }

  spec {
    service_name           = "nginx-service"
    replicas               = 1
    revision_history_limit = 2

    selector {
      match_labels = {
        app = local.test_config.app_name
      }
    }

    template {
      metadata {
        labels = {
          app = local.test_config.app_name
        }
      }

      spec {
        container {
          image = "nginx:alpine"
          name  = "nginx"

          port {
            container_port = 443
          }

          volume_mount {
            name       = "nginx-config"
            mount_path = "/etc/nginx/nginx.conf"
            sub_path   = "nginx.conf"
            read_only  = true
          }

          volume_mount {
            name       = "pki-certs"
            mount_path = "/vault/secrets"
            read_only  = true
          }

          volume_mount {
            name       = "nginx-storage"
            mount_path = "/var/www/html"
            read_only  = false
          }
        }

        volume {
          name = "nginx-config"
          config_map {
            name = kubernetes_config_map.nginx_conf.metadata[0].name
          }
        }

        volume {
          name = "pki-certs"
          secret {
            secret_name = "test-certs"
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "nginx-storage"
        labels = {
          app = local.test_config.app_name
        }
      }
      
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = local.test_config.storage_class
        resources {
          requests = {
            storage = local.test_config.storage_size
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.cni_cilium,
    helm_release.csi_synology
  ]
}

# -----------------------------------------------------------------------------
# NGINX SERVICE
# -----------------------------------------------------------------------------
# ClusterIP service for internal communication

resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.test.metadata[0].name
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "service"
      "app.kubernetes.io/part-of"    = local.test_config.app_name
    }
  }

  spec {
    selector = {
      app = local.test_config.app_name
    }

    port {
      port        = 443
      target_port = 443
    }

    type = "ClusterIP"
  }
}

# -----------------------------------------------------------------------------
# DNS CONFIGURATION
# -----------------------------------------------------------------------------
# UniFi DNS record for internal domain resolution

resource "unifi_dns_record" "dns_test" {
  name        = local.test_config.domain_name
  enabled     = true
  port        = 0
  record_type = "A"
  ttl         = 3600
  value       = local.test_config.loadbalancer_ip
}

# -----------------------------------------------------------------------------
# TLS CERTIFICATES
# -----------------------------------------------------------------------------
# Vault-managed certificates for secure HTTPS communication

module "certificates_test" {
  source     = "../_modules/vso_certificates"
  namespace  = kubernetes_namespace.test.metadata[0].name
  pki_name   = "pki"
  auth_mount = "kubernetes-low-layer"
  pki_issuer = "low-layer.internal"
  pki_role   = "low-layer.internal"
  audience   = "kube.low-layer.internal"
  certificates = [{
    cn           = local.test_config.domain_name
    format       = "pem"
    ttl          = "10m"
    expiryOffset = "1m"
    secretName   = "test-certs"
  }]
}

# -----------------------------------------------------------------------------
# ISTIO GATEWAY CONFIGURATION
# -----------------------------------------------------------------------------
# Gateway for HTTPS traffic on internal network

resource "kubernetes_manifest" "internal_gateway_test" {
  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "Gateway"
    metadata = {
      name      = "test-gateway"
      namespace = "istio-proxy-internal"
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
          hosts = [
            local.test_config.domain_name
          ]
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

  depends_on = [helm_release.istio_base]
}

# -----------------------------------------------------------------------------
# ISTIO VIRTUAL SERVICE
# -----------------------------------------------------------------------------
# Traffic routing from gateway to NGINX service

resource "kubernetes_manifest" "virtualservice_test_internal" {
  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "VirtualService"
    metadata = {
      name      = "test"
      namespace = kubernetes_namespace.test.metadata[0].name
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/component"  = "istio-routing"
      }
    }
    spec = {
      gateways = [
        "${kubernetes_manifest.internal_gateway_test.manifest.metadata.namespace}/${kubernetes_manifest.internal_gateway_test.manifest.metadata.name}"
      ]
      hosts = [
        local.test_config.domain_name
      ]
      tls = [{
        match = [{
          port     = 443
          sniHosts = [
            local.test_config.domain_name
          ]
        }]
        route = [{
          destination = {
            host = "nginx.test.svc.cluster.local"
            port = {
              number = 443
            }
          }
        }]
      }]
    }
  }

  depends_on = [helm_release.istio_base]
}