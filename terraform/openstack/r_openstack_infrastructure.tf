# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# OPENSTACK INFRASTRUCTURE DEPLOYMENT
# =============================================================================
# Deploy OpenStack infrastructure components with RabbitMQ, MariaDB, Memcached and Adminer
# Demonstrates OpenStack foundation services with database administration and service mesh routing

# -----------------------------------------------------------------------------
# OPENSTACK INFRASTRUCTURE CONFIGURATION
# -----------------------------------------------------------------------------
# Centralized configuration for OpenStack environment

locals {
  openstack_config = {
    namespace       = "openstack-infrastructure"
    domain_name     = "adminer.low-layer.internal"
    loadbalancer_ip = data.kubernetes_service.internal_lb.status.0.load_balancer.0.ingress.0.ip
    helm_repository = "https://tarballs.opendev.org/openstack/openstack-helm"
    helm_timeout    = 180
  }
}

# -----------------------------------------------------------------------------
# OPENSTACK INFRASTRUCTURE NAMESPACE
# -----------------------------------------------------------------------------
# Dedicated namespace with Istio ambient mode and security policies

resource "kubernetes_namespace" "openstack_infrastructure" {
  metadata {
    name = local.openstack_config.namespace
    labels = {
      "app.kubernetes.io/managed-by"               = "terraform"
      "app.kubernetes.io/component"                = "openstack-infrastructure"
      "istio.io/dataplane-mode"                    = "ambient"
      "pod-security.kubernetes.io/enforce"         = "baseline"
      "pod-security.kubernetes.io/enforce-version" = "latest"
    }
  }
}

# -----------------------------------------------------------------------------
# RABBITMQ DEPLOYMENT
# -----------------------------------------------------------------------------
# Message broker service for OpenStack components communication

resource "helm_release" "openstack_rabbitmq" {
  name       = "openstack-rabbitmq"
  repository = local.openstack_config.helm_repository
  chart      = "rabbitmq"
  namespace  = kubernetes_namespace.openstack_infrastructure.metadata[0].name
  timeout    = local.openstack_config.helm_timeout

  values = [
    file("helm_values/openstack_rabbitmq_config.yaml"),
  ]
}

# -----------------------------------------------------------------------------
# MARIADB DEPLOYMENT
# -----------------------------------------------------------------------------
# Database service for OpenStack metadata and configuration storage

resource "helm_release" "openstack_mariadb" {
  name       = "openstack-mariadb"
  repository = local.openstack_config.helm_repository
  chart      = "mariadb"
  namespace  = kubernetes_namespace.openstack_infrastructure.metadata[0].name
  timeout    = local.openstack_config.helm_timeout

  values = [
    file("helm_values/openstack_mariadb_config.yaml"),
  ]
}

# -----------------------------------------------------------------------------
# MEMCACHED DEPLOYMENT
# -----------------------------------------------------------------------------
# In-memory caching service for OpenStack performance optimization

resource "helm_release" "openstack_memcached" {
  name       = "openstack-memcached"
  repository = local.openstack_config.helm_repository
  chart      = "memcached"
  namespace  = kubernetes_namespace.openstack_infrastructure.metadata[0].name
  timeout    = local.openstack_config.helm_timeout

  values = [
    file("helm_values/openstack_memcached_config.yaml"),
  ]
}

# -----------------------------------------------------------------------------
# ADMINER DEPLOYMENT
# -----------------------------------------------------------------------------
# Database administration tool with enhanced configuration

resource "kubernetes_deployment" "adminer" {
  metadata {
    name      = "adminer"
    namespace = kubernetes_namespace.openstack_infrastructure.metadata[0].name
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "database-admin"
      "app.kubernetes.io/part-of"    = "openstack-infrastructure"
      app = "adminer"
    }
    annotations = {
      "reloader.stakater.com/auto" = "true"
    }
  }

  spec {
    replicas               = 1
    revision_history_limit = 2

    selector {
      match_labels = {
        app = "adminer"
      }
    }

    template {
      metadata {
        labels = {
          app = "adminer"
        }
      }

      spec {
        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }
        
        node_selector = {
          "openstack-control-plane" = "enabled"
        }

        container {
          image = "adminer:latest"
          name  = "adminer"

          port {
            container_port = 8080
          }
        }
      }
    }
  }
}

# -----------------------------------------------------------------------------
# ADMINER SERVICE
# -----------------------------------------------------------------------------
# ClusterIP service for internal communication

resource "kubernetes_service" "adminer" {
  metadata {
    name      = "adminer"
    namespace = kubernetes_namespace.openstack_infrastructure.metadata[0].name
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "service"
      "app.kubernetes.io/part-of"    = "openstack-infrastructure"
    }
  }
  
  spec {
    selector = {
      app = "adminer"
    }

    port {
      port        = 80
      target_port = 8080
      protocol    = "TCP"
    }
    
    type = "ClusterIP"
  }
}

# -----------------------------------------------------------------------------
# DNS CONFIGURATION
# -----------------------------------------------------------------------------
# UniFi DNS record for internal domain resolution

resource "unifi_dns_record" "dns_adminer" {
  name        = local.openstack_config.domain_name
  enabled     = true
  port        = 0
  record_type = "A"
  ttl         = 3600
  value       = local.openstack_config.loadbalancer_ip
}

# -----------------------------------------------------------------------------
# ISTIO GATEWAY CONFIGURATION
# -----------------------------------------------------------------------------
# Gateway for HTTP traffic on internal network

resource "kubernetes_manifest" "internal_gateway_adminer" {
  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "Gateway"
    metadata = {
      name      = "adminer-gateway"
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
          hosts = [
            local.openstack_config.domain_name
          ]
          port = {
            name     = "http"
            number   = 80
            protocol = "HTTP"
          }
        }
      ]
    }
  }
}

# -----------------------------------------------------------------------------
# ISTIO VIRTUAL SERVICE
# -----------------------------------------------------------------------------
# Traffic routing from gateway to Adminer service

resource "kubernetes_manifest" "virtualservice_adminer" {
  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "VirtualService"
    metadata = {
      name      = "adminer"
      namespace = kubernetes_namespace.openstack_infrastructure.metadata[0].name
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/component"  = "istio-routing"
      }
    }
    spec = {
      gateways = [
        "${data.kubernetes_service.internal_lb.metadata[0].namespace}/${kubernetes_manifest.internal_gateway_adminer.manifest.metadata.name}"
      ]
      hosts = [
        local.openstack_config.domain_name
      ]
      http = [{
        match = [{
          uri = {
            prefix = "/"
          }
        }]
        route = [{
          destination = {
            host = "${kubernetes_service.adminer.metadata[0].name}.${kubernetes_namespace.openstack_infrastructure.metadata[0].name}.svc.cluster.local"
            port = {
              number = 80
            }
          }
        }]
      }]
    }
  }
}